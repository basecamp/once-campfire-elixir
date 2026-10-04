defmodule Campfire.HtmlParser do
  @moduledoc "Persistent native Gumbo parsers pinned to the Rails reference's Nokogiri version."
  use GenServer
  @workers 4

  def children do
    for index <- 0..(@workers - 1) do
      %{id: {__MODULE__, index}, start: {__MODULE__, :start_link, [index]}}
    end
  end

  def start_link(index), do: GenServer.start_link(__MODULE__, index, name: name(index))

  def parse(html) do
    index = :erlang.phash2(self(), @workers)

    case GenServer.call(name(index), {:parse, html}, 30_000) do
      %{"error" => message} -> raise ArgumentError, message
      nodes -> Enum.map(nodes, &decode_node/1)
    end
  end

  defp name(index), do: String.to_atom("Elixir.Campfire.HtmlParser.#{index}")

  defp decode_node([tag, attrs, children]),
    do: {tag, Enum.map(attrs, &List.to_tuple/1), Enum.map(children, &decode_node/1)}

  defp decode_node(%{"comment" => text}), do: {:comment, text}
  defp decode_node(text) when is_binary(text), do: text

  @impl true
  def init(_index) do
    executable = System.find_executable("campfire-html") || raise "campfire-html is unavailable"
    port = Port.open({:spawn_executable, executable}, [:binary, {:packet, 4}, :exit_status])
    {:ok, port}
  end

  @impl true
  def handle_call({:parse, html}, _from, port) do
    true = Port.command(port, html)

    receive do
      {^port, {:data, data}} -> {:reply, Jason.decode!(data), port}
      {^port, {:exit_status, status}} -> {:stop, {:parser_exit, status}, port}
    after
      25_000 -> {:stop, :parser_timeout, port}
    end
  end

  @impl true
  def terminate(_, port) do
    if Port.info(port), do: Port.close(port)
  end
end
