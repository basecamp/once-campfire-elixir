defmodule Campfire.ResponseCache do
  @moduledoc """
  Complete responses for authenticated pages, remembered with their ETag and gzip body.

  Entries are keyed on everything a page depends on besides the database: the user, the
  CSRF session token, route inputs, base URL, User-Agent and Turbo-Frame header. Pages
  whose database inputs are not cheap to enumerate also key on `generation/0`: SQLite's
  `PRAGMA data_version` read on a dedicated connection, which changes whenever any other
  connection commits to the database file, whether in this node, in a separate job node
  or in a Rails process writing the same file. A hit therefore never predates the last
  committed write by anyone. Static files are remembered compressed in a second table.
  """
  use GenServer
  import Plug.Conn
  require Logger
  alias Exqlite.Sqlite3, as: SQL
  @table __MODULE__
  @static Campfire.ResponseCache.Static
  @max_entries 512
  @max_bytes 128 * 1024 * 1024

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@static, [:named_table, :set, :public, read_concurrency: true])
    :persistent_term.put({__MODULE__, :bytes}, :atomics.new(1, signed: false))
    {:ok, db} = SQL.open(Keyword.fetch!(opts, :path), mode: :readonly)
    :ok = SQL.set_busy_timeout(db, 5000)
    {:ok, stmt} = SQL.prepare(db, "PRAGMA data_version")
    {:ok, %{db: db, statement: stmt}}
  end

  @doc "The database's data version: advanced by every commit from any other connection."
  def generation, do: GenServer.call(__MODULE__, :generation)

  # The statement is reset right after its row is read so this connection never holds a
  # WAL read snapshot between requests, which would block checkpoints by other writers.
  # Anything but a row yields a unique value, so the request misses rather than risk a
  # stale hit.
  def handle_call(:generation, _, %{db: db, statement: stmt} = state) do
    version =
      case SQL.step(db, stmt) do
        {:row, [version]} ->
          version

        other ->
          Logger.warning("response cache could not read PRAGMA data_version: #{inspect(other)}")
          :erlang.unique_integer([:positive])
      end

    SQL.reset(stmt)
    {:reply, version, state}
  end

  def terminate(_, %{db: db, statement: stmt}) do
    SQL.release(db, stmt)
    SQL.close(db)
  end

  defp bytes, do: :persistent_term.get({__MODULE__, :bytes}, nil)

  @doc "Entry count and accounted body bytes, for operators and tests."
  def stats do
    %{
      entries: :ets.info(@table, :size),
      bytes: if(ref = bytes(), do: :atomics.get(ref, 1), else: 0)
    }
  end

  def clear do
    :ets.delete_all_objects(@table)
    if ref = bytes(), do: :atomics.put(ref, 1, 0)
    :ok
  end

  @doc """
  Send a 200 response, from the cache when `terms` identify a remembered page.

  `terms` of nil disables caching for this response (flash messages, errors). The
  rendered body is remembered by `Campfire.HttpResponse` once its ETag and compressed
  form are known.
  """
  def send(conn, nil, render), do: send_resp(conn, 200, render.())

  def send(conn, terms, render) do
    key = :crypto.hash(:sha256, :erlang.term_to_binary(terms))

    case :ets.lookup(@table, key) do
      [{^key, entry}] ->
        conn |> assign(:response_cache_hit, entry) |> send_resp(200, entry.body)

      [] ->
        conn |> assign(:response_cache_store, key) |> send_resp(200, render.())
    end
  end

  def store(key, body, etag, gzip, preload) when is_binary(body) do
    entry = %{key: key, body: body, etag: etag, gzip: gzip, preload: preload}

    if within_budget?(key, size(entry)) do
      :ets.insert(@table, {key, entry})
    end

    :ok
  end

  @doc "Add the compressed body to an entry first stored for an identity-encoding client."
  def put_gzip(%{key: key}, gzip) when is_binary(gzip) do
    case :ets.lookup(@table, key) do
      [{^key, %{gzip: nil} = current}] ->
        entry = %{current | gzip: gzip}
        if within_budget?(key, size(entry)), do: :ets.insert(@table, {key, entry})
        :ok

      _ ->
        :ok
    end
  end

  defp size(%{body: body, gzip: gzip}),
    do: byte_size(body) + if(gzip, do: byte_size(gzip), else: 0)

  # Accounts for the bytes `entry_size` will occupy under `key`, replacing whatever that key
  # holds now. When the table would exceed its limits everything is dropped instead and the
  # caller skips its insert; the next miss stores it afresh.
  defp within_budget?(key, entry_size) do
    ref = bytes()

    current =
      case :ets.lookup(@table, key) do
        [{^key, existing}] -> size(existing)
        [] -> 0
      end

    total = if ref, do: :atomics.get(ref, 1), else: 0

    cond do
      current == 0 and :ets.info(@table, :size) >= @max_entries ->
        clear()
        false

      total - current + entry_size > @max_bytes ->
        clear()
        false

      true ->
        if ref, do: :atomics.add(ref, 1, entry_size - current)
        true
    end
  end

  @doc "Remember an immutable static file derivative under `key`."
  def static(key, compute) do
    case :ets.lookup(@static, key) do
      [{^key, value}] ->
        value

      [] ->
        value = compute.()
        :ets.insert(@static, {key, value})
        value
    end
  end
end
