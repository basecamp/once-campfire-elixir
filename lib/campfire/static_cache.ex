defmodule Campfire.StaticCache do
  @moduledoc """
  Public files and assets held in memory with their gzip form, bounded, independent of the
  database.

  Files under `priv/` are fixed for the life of a release, so entries never expire. An entry
  holds the file's bytes and its Last-Modified value; its Rack-framed gzip body is added the
  first time a gzip response is negotiated, so identity, conditional and range requests never
  compress anything, exactly as before. Responses are served byte for byte as the disk path
  would produce them (the gzip timestamp is stamped per response). Lookups read the ETS table
  directly from the request process; admission goes through the owning process, which keeps
  the byte accounting exact and evicts the oldest entries first. The budget counts file and
  gzip bytes. `CAMPFIRE_STATIC_CACHE_MB` sets it (default 32); 0 disables the cache, and
  requests then never touch the owning process. If the owner is unavailable, files are
  served from disk as before.
  """
  use GenServer
  @table __MODULE__
  @limit {__MODULE__, :limit}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    :ets.new(@table, [:named_table, :set, :protected, read_concurrency: true])
    limit = Keyword.get(opts, :limit_bytes, limit_from_env())
    :persistent_term.put(@limit, limit)
    {:ok, %{limit: limit, bytes: 0, queue: :queue.new()}}
  end

  defp limit_from_env do
    case Integer.parse(System.get_env("CAMPFIRE_STATIC_CACHE_MB", "32")) do
      {mb, ""} when mb >= 0 -> mb * 1024 * 1024
      _ -> 32 * 1024 * 1024
    end
  end

  @doc "The budget in bytes; 0 when the cache is disabled or not running."
  def limit, do: :persistent_term.get(@limit, 0)

  @doc """
  The entry for `path`: `%{body: binary, modified: String.t(), gzip: binary | nil}`.

  On a miss `compute` returns the body and Last-Modified value; the entry is admitted when it
  fits the budget and returned either way. Without a budget, or without a running owner, the
  computed entry is returned and nothing is kept.
  """
  def fetch(path, compute) do
    case limit() > 0 && lookup(path) do
      {:ok, entry} ->
        entry

      _ ->
        entry = Map.put(compute.(), :gzip, nil)
        if limit() > 0 && byte_size(entry.body) <= limit(), do: owner({:admit, path, entry})
        entry
    end
  end

  @doc """
  The gzip body for an entry, computed by `compress` the first time a gzip response is
  negotiated and kept with the entry when the extra bytes fit the budget.
  """
  def gzip(_path, %{gzip: gzip}, _compress) when is_binary(gzip), do: gzip

  def gzip(path, _entry, compress) do
    gzip = compress.()
    if limit() > 0 && byte_size(gzip) <= limit(), do: owner({:put_gzip, path, gzip})
    gzip
  end

  @doc "Entry count, accounted bytes and the budget."
  def stats, do: GenServer.call(__MODULE__, :stats)

  @doc "Replace the budget and drop every entry (tests)."
  def configure(limit_bytes), do: GenServer.call(__MODULE__, {:configure, limit_bytes})

  # The table belongs to the owner; while it is restarting, lookups miss instead of raising.
  defp lookup(path) do
    case :ets.lookup(@table, path) do
      [{^path, entry}] -> {:ok, entry}
      [] -> :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp owner(message) do
    GenServer.call(__MODULE__, message)
  catch
    :exit, _ -> :skipped
  end

  def handle_call({:admit, path, entry}, _, state) do
    size = size(entry)

    cond do
      size > state.limit -> {:reply, :skipped, state}
      :ets.member(@table, path) -> {:reply, :ok, state}
      true -> {:reply, :ok, insert(state, path, entry, size)}
    end
  end

  def handle_call({:put_gzip, path, gzip}, _, state) do
    case :ets.lookup(@table, path) do
      [{^path, %{gzip: nil} = entry}] ->
        size = byte_size(gzip)

        if size(entry) + size > state.limit do
          {:reply, :skipped, state}
        else
          # Other entries make room; this one stays where it is in the queue.
          state = make_room(state, size, path)
          :ets.insert(@table, {path, %{entry | gzip: gzip}})
          {:reply, :ok, %{state | bytes: state.bytes + size}}
        end

      _ ->
        {:reply, :skipped, state}
    end
  end

  def handle_call(:stats, _, state),
    do:
      {:reply, %{entries: :ets.info(@table, :size), bytes: state.bytes, limit: state.limit},
       state}

  def handle_call({:configure, limit}, _, state) do
    :ets.delete_all_objects(@table)
    :persistent_term.put(@limit, limit)
    {:reply, :ok, %{state | limit: limit, bytes: 0, queue: :queue.new()}}
  end

  def terminate(_, _), do: :persistent_term.put(@limit, 0)

  defp insert(state, path, entry, size) do
    state = make_room(state, size, nil)
    :ets.insert(@table, {path, entry})
    %{state | bytes: state.bytes + size, queue: :queue.in(path, state.queue)}
  end

  defp size(%{body: body, gzip: gzip}),
    do: byte_size(body) + if(is_binary(gzip), do: byte_size(gzip), else: 0)

  # Evicts the oldest entries until `size` more bytes fit, never evicting `keep`.
  defp make_room(state, size, _keep) when state.bytes + size <= state.limit, do: state

  defp make_room(state, size, keep) do
    case :queue.out(state.queue) do
      {{:value, ^keep}, queue} when keep != nil ->
        # The kept entry moves to the back so older entries still leave first.
        make_room(%{state | queue: :queue.in(keep, queue)}, size, keep)

      {{:value, oldest}, queue} ->
        freed =
          case :ets.lookup(@table, oldest) do
            [{^oldest, entry}] -> size(entry)
            [] -> 0
          end

        :ets.delete(@table, oldest)
        make_room(%{state | bytes: state.bytes - freed, queue: queue}, size, keep)

      {:empty, _} ->
        state
    end
  end
end
