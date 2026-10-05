defmodule Campfire.FragmentCache do
  @moduledoc """
  In-process cache for rendered message and boost fragments, shared by request
  and broadcast rendering.

  Entries are keyed by record identity and validated against the record's
  `updated_at`, matching Rails' `cache [message, "presentation-v3"]` versioning:
  touching a record invalidates its fragment. The table is bounded by total
  fragment bytes and is emptied when it exceeds the limit.

  Each fragment can also retain values derived from its HTML, such as its
  precompressed gzip pieces (see `Campfire.HttpCompression`), so cached
  fragments are compressed once rather than on every response.
  """
  use GenServer

  @table __MODULE__
  @max_bytes 64 * 1024 * 1024

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl GenServer
  def init(nil) do
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.insert(@table, {:bytes, 0})
    {:ok, nil}
  end

  def record(kind, record, render) do
    {key, version} = identity(kind, record)
    fetch(key, version, render)
  end

  def records(kind, records, render) do
    Enum.map(records, fn record ->
      {key, version} = identity(kind, record)
      fetch(key, version, fn -> render.(record) end)
    end)
  end

  @doc "Like `records/3`, returning `{:fragment, key, version, html}` parts for gzip splicing."
  def parts(kind, records, render) do
    Enum.map(records, fn record ->
      {key, version} = identity(kind, record)
      {:fragment, key, version, fetch(key, version, fn -> render.(record) end)}
    end)
  end

  @doc """
  A value derived from a cached fragment's HTML, such as its precompressed
  gzip piece, computed on first use and retained with the fragment.
  """
  def derived(key, version, html, name, compute) do
    case :ets.lookup(@table, key) do
      [{_, ^version, _, %{^name => value}}] ->
        value

      [{_, ^version, _, derived}] when map_size(derived) < 8 ->
        value = compute.(html)
        :ets.insert(@table, {key, version, html, Map.put(derived, name, value)})
        value

      _ ->
        compute.(html)
    end
  end

  defp fetch(key, version, render) do
    case :ets.lookup(@table, key) do
      [{_, ^version, html, _}] ->
        html

      _ ->
        html = render.()
        size = byte_size(html)

        # The default covers a concurrent wipe, which briefly removes the counter.
        if :ets.update_counter(@table, :bytes, size, {:bytes, 0}) > @max_bytes do
          :ets.delete_all_objects(@table)
          :ets.insert(@table, {:bytes, size})
        end

        :ets.insert(@table, {key, version, html, %{}})
        html
    end
  end

  defp identity(:message, record), do: {{:message, record["id"]}, record["updated_at"]}
  defp identity(:boost, record), do: {{:boost, record["id"]}, record["updated_at"]}
end
