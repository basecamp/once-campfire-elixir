defmodule Campfire.FragmentCache do
  @moduledoc """
  In-process cache for rendered message and boost fragments, shared by request
  and broadcast rendering.

  Entries are keyed by record identity and validated against the record's
  `updated_at`, matching Rails' `cache [message, "presentation-v3"]` versioning:
  touching a record invalidates its fragment. The table is bounded by total
  fragment bytes; past the limit, entries are evicted until it is back to three
  quarters of it.

  Each fragment can also retain values derived from its HTML, such as its
  precompressed gzip pieces (see `Campfire.HttpCompression`), so cached
  fragments are compressed once rather than on every response.
  """
  use GenServer

  @table __MODULE__
  # Memoized values (page shells, compressed page text, finished responses, parsed headers) are
  # bounded separately, so their churn never evicts the message fragments, nor the reverse.
  @memo Module.concat(__MODULE__, Memo)
  @default_bytes 64 * 1024 * 1024

  # Accounting: each entry is {key, version, value, derived, size} and records the bytes it was
  # counted for. The :bytes counter is raised before an entry becomes visible and lowered only by
  # whoever takes that entry out, by its recorded size, so it never undercounts the table, even
  # with concurrent writers and evictors. Past the limit, entries are taken until the counter is
  # back to three quarters of it.

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl GenServer
  def init(nil) do
    for table <- [@table, @memo] do
      :ets.new(table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

      :ets.insert(table, {:bytes, 0})
      :persistent_term.put({__MODULE__, table}, @default_bytes)
    end

    {:ok, nil}
  end

  @doc false
  # The byte limit of `table` (this module or its memo table), for tests.
  def set_limit(table, bytes), do: :persistent_term.put({__MODULE__, table}, bytes)

  @doc false
  def bytes(table), do: :ets.lookup_element(table, :bytes, 2, 0)

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
  gzip piece, computed on first use and retained (and counted) with the fragment.
  """
  def derived(key, version, html, name, compute) do
    case :ets.lookup(@table, key) do
      [{_, ^version, _, %{^name => value}, _}] ->
        value

      [{_, ^version, _, derived, size}] when map_size(derived) < 8 ->
        value = compute.(html)
        extra = derived_size(value)
        :ets.update_counter(@table, :bytes, extra, {:bytes, 0})

        # Only the entry as it was read gets the value; if a concurrent store or eviction
        # replaced it, the count is given back.
        replaced =
          :ets.select_replace(@table, [
            {{key, version, :"$1", :"$2", size}, [{:"=:=", :"$2", {:const, derived}}],
             [
               {{{:const, key}, {:const, version}, :"$1", {:const, Map.put(derived, name, value)},
                 size + extra}}
             ]}
          ])

        if replaced == 0,
          do: :ets.update_counter(@table, :bytes, -extra, {:bytes, 0}),
          else: evict(@table)

        value

      _ ->
        compute.(html)
    end
  end

  @doc """
  A value that depends only on `key`, such as a deterministic signature or the gzip piece of a
  page's per-request text keyed by its digest, computed on first use. It is bounded with the
  other memoized values, counting `size` bytes (the value's own size when it is a binary).
  """
  def memo(key, compute), do: memo(key, nil, compute)

  @doc """
  Like `memo/2`, counting `size` bytes, or what `size` returns for the value when it is a
  function. A `nil` result is returned but not kept.
  """
  def memo(key, size, compute) do
    case :ets.lookup(@memo, key) do
      [{_, :memo, value, _, _}] ->
        value

      _ ->
        case compute.() do
          nil ->
            nil

          value ->
            store(@memo, {key, :memo, value, %{}, size_of(size, value)})
            value
        end
    end
  end

  defp size_of(nil, value), do: memo_size(value)
  defp size_of(size, value) when is_function(size, 1), do: size.(value)
  defp size_of(size, _value), do: size

  defp memo_size(value) when is_binary(value), do: byte_size(value)
  defp memo_size({piece, _crc, _size}) when is_binary(piece), do: byte_size(piece)
  defp memo_size(_), do: 64

  defp derived_size(value) when is_binary(value), do: byte_size(value)
  defp derived_size({piece, _crc, _size}) when is_binary(piece), do: byte_size(piece)
  defp derived_size(_), do: 64

  defp fetch(key, version, render) do
    case :ets.lookup(@table, key) do
      [{_, ^version, html, _, _}] ->
        html

      _ ->
        html = render.()
        store(@table, {key, version, html, %{}, byte_size(html)})
        html
    end
  end

  # Counted first, then inserted. An entry already under the key (an older version, or a
  # concurrent writer's) is taken out with its own recorded size before retrying.
  defp store(table, entry) do
    :ets.update_counter(table, :bytes, elem(entry, 4), {:bytes, 0})
    insert(table, entry)
    evict(table)
  end

  defp insert(table, entry) do
    unless :ets.insert_new(table, entry) do
      take(table, elem(entry, 0))
      insert(table, entry)
    end
  end

  defp take(table, key) do
    for {_, _, _, _, size} <- :ets.take(table, key),
        do: :ets.update_counter(table, :bytes, -size, {:bytes, 0})
  end

  defp evict(table) do
    limit = :persistent_term.get({__MODULE__, table})

    if bytes(table) > limit do
      target = div(limit * 3, 4)
      evict(table, :ets.select(table, [{{:"$1", :_, :_, :_, :_}, [], [:"$1"]}], 64), target)
    end

    :ok
  end

  defp evict(_table, :"$end_of_table", _target), do: :ok

  defp evict(table, {keys, continuation}, target) do
    Enum.each(keys, &take(table, &1))
    if bytes(table) > target, do: evict(table, :ets.select(continuation), target)
  end

  defp identity(:message, record), do: {{:message, record["id"]}, record["updated_at"]}
  defp identity(:boost, record), do: {{:boost, record["id"]}, record["updated_at"]}
end
