defmodule Campfire.FragmentCache do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils

  @moduledoc """
  Bounded application fragments shared by request and broadcast rendering.

  Every entry is keyed by the SQLite generation captured for the render, the request
  origin, and the record's own version. A generation change retires every key, an
  origin change isolates fragments whose links carry it, and renders outside a request
  share one scope so a broadcast and a page never disagree.

  The store is bounded by bytes the way the reference's `MemoryStore` is: reads count as
  uses, a write past `CAMPFIRE_FRAGMENT_CACHE_MB` (default 32) drops least recently used
  entries until the store is back to three quarters of it, and an entry larger than a
  quarter of it is served but not kept.

  Entries live in ETS rather than in a process: a render is on the request path, and a lookup
  that copies the fragment straight to the caller's heap needs no message to anything. The byte
  budget is a counter and pruning runs in the caller, so this module owns no process at all.
  """

  @entry_overhead 240
  @default_megabytes 32
  @table :campfire_fragments
  # Recency index so pruning retires the oldest entry with :ets.first/1 instead of walking the table
  # on the request path: this ran in the posting request's own process, which is where a live sample
  # found four of them parked in :ets.tab2list.
  @order :campfire_fragment_order
  @counter {__MODULE__, :counter}

  @external_resource "vectors/fragment-digests.json"
  @digests Campfire.JSON.decode!(File.read!(@external_resource))

  @doc "The table this cache uses; owned by Campfire.Tables."
  def table, do: @table

  @doc "Creates the table and its byte counter; called once from Campfire.Tables."
  def setup do
    :ets.new(@order, [
      :public,
      :named_table,
      :ordered_set,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@table, [
      :public,
      :named_table,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    :persistent_term.put(@counter, :atomics.new(1, signed: true))
    :ok
  end

  def record(kind, record, render) do
    fetch(identity(kind, record), render)
  end

  def clear do
    if :ets.whereis(@table) != :undefined, do: :ets.delete_all_objects(@table)
    if :ets.whereis(@order) != :undefined, do: :ets.delete_all_objects(@order)
    :atomics.put(counter(), 1, 0)
    :ok
  end

  def size do
    if :ets.whereis(@table) == :undefined, do: 0, else: :ets.info(@table, :size)
  end

  def bytes, do: :atomics.get(counter(), 1)

  def fetch(key, render) do
    case scope() do
      nil ->
        render.()

      scope ->
        key = {scope, key}

        case lookup(key) do
          {:ok, html} -> html
          :miss -> store(key, render.())
        end
    end
  end

  @doc """
  Fetches a collection of fragments in entry order with one pass over the store.

  `entries` are `{kind, record}` pairs and `render_misses` receives the entries that missed, in
  order, returning their HTML. That is what lets a page render preload only what it has to
  render: hits cost the lookup and nothing else, and a fully warm batch runs no callback.
  """
  def fetch_many(entries, render_misses)

  def fetch_many([], _render_misses), do: []

  def fetch_many(entries, render_misses) do
    case scope() do
      nil ->
        render_misses.(entries)

      scope ->
        keys = Enum.map(entries, fn {kind, record} -> {scope, identity(kind, record)} end)
        lookups = Enum.map(keys, &lookup/1)

        missed = for {:miss, index} <- Enum.with_index(lookups), do: index

        rendered =
          if missed == [], do: [], else: render_misses.(Enum.map(missed, &Enum.at(entries, &1)))

        stored =
          Enum.map(Enum.zip(missed, rendered), fn {index, html} ->
            store(Enum.at(keys, index), html)
          end)

        from_cache = Map.new(Enum.zip(missed, stored))

        for {lookup, index} <- Enum.with_index(lookups) do
          case lookup do
            {:ok, html} -> html
            :miss -> Map.fetch!(from_cache, index)
          end
        end
    end
  end

  defp scope do
    epoch = Campfire.ResponseCache.fragment_epoch()

    if epoch == nil || !Campfire.ResponseCache.fragment_valid?() do
      nil
    else
      {epoch, Process.get(:campfire_request_base, "detached")}
    end
  end

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{_, used, %{html: html}}] ->
        touch(key, used)
        {:ok, html}

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp store(key, html) do
    case :ets.lookup(@table, key) do
      [{_, used, %{html: stored}}] ->
        touch(key, used)
        stored

      [] ->
        size = :erlang.external_size(key) + byte_size(html) + @entry_overhead

        if size > div(limit(), 4) do
          html
        else
          # Reserve before inserting: one atomic read-modify-write decides admission and accounts for it,
          # so admissions from different request processes cannot overshoot the budget or leave an entry
          # that the counter never saw.
          admit(key, html, size)
        end
    end
  rescue
    ArgumentError -> html
  end

  # Reserve before inserting so an admitted fragment is always counted, and if the budget is full make
  # room for this fragment (the least recently used first) rather than refusing it.
  defp admit(key, html, size) do
    if :atomics.add_get(counter(), 1, size) <= limit() do
      insert(key, html, size)
    else
      :atomics.sub(counter(), 1, size)
      drop_oldest(limit() - size)

      if :atomics.add_get(counter(), 1, size) <= limit() do
        insert(key, html, size)
      else
        :atomics.sub(counter(), 1, size)
        html
      end
    end
  end

  defp insert(key, html, size) do
    used = :erlang.monotonic_time()
    :ets.insert(@table, {key, used, %{html: html, size: size}})
    :ets.insert(@order, {{used, key}})
    prune()
    html
  end

  defp prune do
    limit = limit()

    if bytes() > limit do
      target = div(limit, 4) * 3
      drop_oldest(target)
    else
      :ok
    end
  end

  # Moves an entry to the front of the recency index; two keys can briefly exist for one entry under
  # concurrent hits, which pruning tolerates by skipping keys whose slot already moved.
  defp touch(key, used) do
    now = :erlang.monotonic_time()
    :ets.delete(@order, {used, key})
    :ets.insert(@order, {{now, key}})
    :ets.update_element(@table, key, {2, now})
  rescue
    ArgumentError -> :ok
  end

  defp drop_oldest(target) do
    if bytes() > target do
      case :ets.first(@order) do
        :"$end_of_table" ->
          :ok

        {used, key} ->
          :ets.delete(@order, {used, key})

          case :ets.lookup(@table, key) do
            [{_, ^used, %{size: size}}] ->
              :ets.delete(@table, key)
              :atomics.sub(counter(), 1, size)
              drop_oldest(target)

            _ ->
              # The entry moved (a concurrent hit re-touched it) or is gone: try the next key.
              drop_oldest(target)
          end
      end
    else
      :ok
    end
  end

  defp counter, do: :persistent_term.get(@counter)

  defp identity(kind, record) do
    table = if kind == :message, do: "messages", else: "boosts"
    template = if kind == :message, do: "messages/_message", else: "messages/boosts/_boost"
    suffix = if kind == :message, do: "/presentation-v3", else: ""
    key = "views/#{template}:#{@digests[template]}/#{table}/#{record["id"]}#{suffix}"

    version =
      record["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.pad_trailing(20, "0")

    {key, version}
  end

  defp limit do
    case Integer.parse(Campfire.Env.get("CAMPFIRE_FRAGMENT_CACHE_MB", "#{@default_megabytes}")) do
      {megabytes, ""} when megabytes >= 0 -> megabytes * 1024 * 1024
      _ -> 0
    end
  end
end
