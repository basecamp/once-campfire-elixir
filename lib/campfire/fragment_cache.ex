defmodule Campfire.FragmentCache do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Bounded application fragments shared by request and broadcast rendering."
  use Agent

  def start_link(_) do
    Agent.start_link(
      fn ->
        :ets.new(__MODULE__, [
          :named_table,
          :set,
          :protected,
          read_concurrency: true
        ])

        :ok
      end,
      name: __MODULE__
    )
  end

  @external_resource "vectors/fragment-digests.json"
  @digests Jason.decode!(File.read!(@external_resource))

  def record(kind, record, render) do
    fetch(identity(kind, record), render)
  end

  def records(_kind, [], _render), do: []

  def records(kind, records, render) do
    Enum.map(records, &record(kind, &1, fn -> render.(&1) end))
  end

  def clear do
    Agent.get_and_update(__MODULE__, fn state ->
      :ets.delete_all_objects(__MODULE__)
      {:ok, state}
    end)
  end

  defp identity(kind, record) do
    table = if kind == :message, do: "messages", else: "boosts"
    template = if kind == :message, do: "messages/_message", else: "messages/boosts/_boost"
    suffix = if kind == :message, do: "/presentation-v3", else: ""
    key = "views/#{template}:#{@digests[template]}/#{table}/#{record["id"]}#{suffix}"

    version =
      record["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.pad_trailing(20, "0")

    {key, version}
  end

  @doc """
  Rendered records as page parts, `{:fragment, key, html}`. `key` identifies
  the cached fragment, or is `nil` when this request does not cache fragments,
  so values derived from its html can be cached next to it with `derived/4`.
  """
  def parts(kind, records, render) do
    for record <- records do
      case cache_key(identity(kind, record)) do
        nil -> {:fragment, nil, render.(record)}
        key -> {:fragment, key, cached(key, fn -> render.(record) end)}
      end
    end
  end

  @doc """
  Splits a rendered page at `marker`, the placeholder standing in for `parts`,
  returning the response iodata and the page's parts, which
  `Campfire.HttpResponse` uses for the ETag. Returns `nil` when the marker is
  absent.
  """
  def splice(html, marker, parts) do
    case :binary.split(html, marker) do
      [before, rest] ->
        parts = [{:raw, before} | parts] ++ [{:raw, rest}]
        {Enum.map(parts, &part_data/1), parts}

      [_] ->
        nil
    end
  end

  def part_data({:raw, data}), do: data
  def part_data({:fragment, _key, html}), do: html

  @doc "A value computed from a fragment's html, cached with the fragment."
  def derived(nil, _tag, html, fun), do: fun.(html)
  def derived(key, tag, html, fun), do: cached({:derived, key, tag}, fn -> fun.(html) end)

  def fetch(key, render) do
    case cache_key(key) do
      nil -> render.()
      key -> cached(key, render)
    end
  end

  defp cache_key(key) do
    epoch = Campfire.ResponseCache.fragment_epoch()

    if epoch != nil and Campfire.ResponseCache.fragment_valid?(),
      do: {epoch, Process.get(:campfire_request_host), key}
  end

  defp cached(key, render) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, html}] ->
        html

      [] ->
        html = render.()

        Agent.get_and_update(__MODULE__, fn state ->
          case :ets.lookup(__MODULE__, key) do
            [{^key, existing}] ->
              {existing, state}

            [] ->
              if :ets.info(__MODULE__, :size) >= 4096,
                do: :ets.delete_all_objects(__MODULE__)

              :ets.insert(__MODULE__, {key, html})
              {html, state}
          end
        end)
    end
  end
end
