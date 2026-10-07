defmodule Campfire.HtmlParser do
  @moduledoc "Bounded, fault-isolated Gumbo parsers pinned to the Rails reference's Nokogiri version."
  use GenServer
  @workers 4
  @recycle_output_bytes 1_048_576

  def children do
    for index <- 0..(@workers - 1) do
      %{id: {__MODULE__, index}, start: {__MODULE__, :start_link, [index]}}
    end
  end

  def start_link(index), do: GenServer.start_link(__MODULE__, index, name: name(index))

  def parse(html) do
    index = :erlang.phash2(self(), @workers)

    case GenServer.call(name(index), {:parse, html}, 30_000) do
      {:error, message} -> raise ArgumentError, message
      %{"error" => message} -> raise ArgumentError, message
      nodes -> Enum.map(nodes, &decode_node/1)
    end
  end

  @impl true
  def init(_index) do
    Process.flag(:trap_exit, true)
    {:ok, open_port()}
  end

  @impl true
  def handle_call({:parse, html}, _from, port) do
    if port_command(port, html) do
      receive do
        {^port, {:data, data}} ->
          {:reply, Jason.decode!(data), recycle_after_large_output(port, data)}

        {^port, {:exit_status, status}} ->
          message = "isolated HTML parser exited with status #{status}"
          {:reply, {:error, message}, open_port()}

        {:EXIT, ^port, reason} ->
          message = "isolated HTML parser exited: #{inspect(reason)}"
          {:reply, {:error, message}, open_port()}
      after
        27_000 ->
          Port.close(port)
          {:reply, {:error, "isolated HTML parser timed out"}, open_port()}
      end
    else
      {:reply, {:error, "isolated HTML parser exited before parsing"}, open_port()}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, _status}}, port), do: {:noreply, open_port()}

  def handle_info({port, {:exit_status, _status}}, current) when is_port(port),
    do: {:noreply, current}

  def handle_info({:EXIT, port, _reason}, port), do: {:noreply, open_port()}

  def handle_info({:EXIT, port, _reason}, current) when is_port(port),
    do: {:noreply, current}

  @impl true
  def terminate(_, port) do
    if Port.info(port), do: Port.close(port)
  end

  defp open_port do
    executable = Path.join(:code.priv_dir(:campfire), "native/campfire-html")

    Port.open({:spawn_executable, String.to_charlist(executable)}, [
      :binary,
      {:packet, 4},
      :exit_status
    ])
  end

  defp port_command(port, html) do
    Port.command(port, html)
  rescue
    ArgumentError -> false
  end

  defp recycle_after_large_output(port, data) when byte_size(data) >= @recycle_output_bytes do
    Port.close(port)
    open_port()
  end

  defp recycle_after_large_output(port, _data), do: port

  defp name(index), do: String.to_atom("Elixir.Campfire.HtmlParser.#{index}")

  defp decode_node([tag, attrs, children]),
    do: {tag, Enum.map(attrs, &List.to_tuple/1), Enum.map(children, &decode_node/1)}

  defp decode_node(%{"comment" => text}), do: {:comment, text}
  defp decode_node(text) when is_binary(text), do: text
end
