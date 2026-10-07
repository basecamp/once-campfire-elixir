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

  def handle_call(:generation, _, %{db: db, statement: stmt} = state) do
    :ok = SQL.reset(stmt)
    {:row, [version]} = SQL.step(db, stmt)
    {:reply, version, state}
  end

  def terminate(_, %{db: db, statement: stmt}) do
    SQL.release(db, stmt)
    SQL.close(db)
  end

  defp bytes, do: :persistent_term.get({__MODULE__, :bytes}, nil)

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
    ref = bytes()
    size = byte_size(body) + if(gzip, do: byte_size(gzip), else: 0)

    if :ets.info(@table, :size) >= @max_entries ||
         (ref && :atomics.get(ref, 1) + size > @max_bytes),
       do: clear()

    if ref, do: :atomics.add(ref, 1, size)

    :ets.insert(
      @table,
      {key, %{key: key, body: body, etag: etag, gzip: gzip, preload: preload}}
    )

    :ok
  end

  def put_gzip(%{key: key} = entry, gzip) do
    :ets.insert(@table, {key, %{entry | gzip: gzip}})
    if ref = bytes(), do: :atomics.add(ref, 1, byte_size(gzip))
    :ok
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
