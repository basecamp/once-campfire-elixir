defmodule Campfire.DB do
  @moduledoc """
  SQLite access through pooled connections.

  `SELECT` statements run on a pool of read-only WAL connections; every other
  statement and every transaction runs on the single writer connection, so
  writes stay serialized exactly as with Rails' one-writer SQLite setup.
  Connections are checked out into the calling process and keep a bounded
  cache of prepared statements.

  `cached/3` keeps a read's rows until a table it reads is written. Every write bumps its
  table's generation after it commits, so a result is only ever stored under generations at
  least as old as any write it missed. Commits by other processes (another SQLite client) are
  seen through the WAL index's change counter, and invalidate everything.
  """
  use Supervisor
  alias Exqlite.Sqlite3, as: SQL

  @writer Campfire.DB.Writer
  @readers Campfire.DB.Readers
  @generations Campfire.DB.Generations

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Supervisor
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    readers = Keyword.get(opts, :readers, System.schedulers_online())

    :ets.new(@generations, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    :persistent_term.put({__MODULE__, :wal_index}, path <> "-shm")

    children = [
      Supervisor.child_spec(
        {NimblePool,
         worker: {__MODULE__.Connection, {:writer, path}}, pool_size: 1, name: @writer},
        id: @writer
      ),
      Supervisor.child_spec(
        {NimblePool,
         worker: {__MODULE__.Connection, {:reader, path}}, pool_size: readers, name: @readers},
        id: @readers
      )
    ]

    # Readers open the file read-only, so the writer must create it first.
    Supervisor.init(children, strategy: :rest_for_one)
  end

  def query(sql, params \\ []) do
    run_safely = fn conn ->
      try do
        run(conn, sql, params)
      rescue
        e -> {:error, e}
      end
    end

    if read?(sql) do
      checkout(@readers, 5_000, run_safely)
    else
      checkout(@writer, 5_000, fn conn ->
        result = run_safely.(conn)
        written([written_table(sql)])
        result
      end)
    end
  end

  def one(sql, params \\ []), do: List.first(query(sql, params))

  @doc """
  `query/2` for a read whose rows are kept until one of `tables` (every table it reads) is
  written, here or by another SQLite client.
  """
  def cached(sql, params, tables) do
    key = {:query, sql, params, generations(tables)}

    case Campfire.FragmentCache.memo(key, &(:erlang.external_size(&1) + 64), fn ->
           case query(sql, params) do
             rows when is_list(rows) -> {:rows, rows}
             _ -> nil
           end
         end) do
      {:rows, rows} -> rows
      nil -> query(sql, params)
    end
  end

  def cached_one(sql, params, tables), do: List.first(cached(sql, params, tables))

  defp generations(tables) do
    outside_commits()
    [generation(:all) | Enum.map(tables, &generation/1)]
  end

  defp generation(table), do: :ets.lookup_element(@generations, table, 2, 0)

  # Bumps the written tables after their commit; `:all` invalidates every cached read.
  defp written(tables) do
    for table <- Enum.uniq(tables), do: :ets.update_counter(@generations, table, 1, {table, 0})
    :ets.insert(@generations, {:wal, wal_state()})
  end

  @doc false
  def invalidate_all, do: written([:all])

  # Every commit, by any client, changes the WAL index header (its transaction counter iChange
  # and mxFrame), which a raw read sees as SQLite maps the same pages. Checked once per request
  # (Campfire.HttpResponse clears the marker) and on every lookup outside one.
  defp outside_commits do
    unless Process.get(:campfire_db_checked) do
      if Process.get(:campfire_request), do: Process.put(:campfire_db_checked, true)
      state = wal_state()

      case :ets.lookup(@generations, :wal) do
        [{:wal, ^state}] -> :ok
        # The first observation is the baseline: nothing was cached before it.
        [] -> :ets.insert_new(@generations, {:wal, state})
        _ -> written([:all])
      end
    end
  end

  defp wal_state do
    with path when is_binary(path) <- :persistent_term.get({__MODULE__, :wal_index}, nil),
         {:ok, file} <- :file.open(path, [:read, :raw, :binary]) do
      try do
        case :file.pread(file, 0, 48) do
          {:ok, header} -> header
          _ -> :none
        end
      after
        :file.close(file)
      end
    else
      _ -> :none
    end
  end

  # The table an INSERT, UPDATE, DELETE or REPLACE writes; anything else is :all.
  defp written_table(sql) do
    case Regex.run(
           ~r/\A\s*(?:INSERT(?:\s+OR\s+\w+)?\s+INTO|REPLACE\s+INTO|UPDATE(?:\s+OR\s+\w+)?|DELETE\s+FROM)\s+"?(\w+)"?/i,
           sql
         ) do
      [_, table] -> table
      nil -> :all
    end
  end

  def transaction(fun) do
    checkout(@writer, 30_000, fn {db, _} = conn ->
      :ok = SQL.execute(db, "BEGIN IMMEDIATE")

      Process.put(:campfire_db_written, [])

      try do
        result =
          fun.(fn sql, params ->
            unless read?(sql),
              do:
                Process.put(:campfire_db_written, [
                  written_table(sql) | Process.get(:campfire_db_written)
                ])

            run(conn, sql, params)
          end)

        :ok = SQL.execute(db, "COMMIT")
        result
      rescue
        e ->
          SQL.execute(db, "ROLLBACK")
          {:error, e}
      after
        written(Process.delete(:campfire_db_written) || [:all])
      end
    end)
  end

  def restore_fixture(fixture) do
    checkout(@writer, 30_000, fn {db, _} = conn ->
      :ok = SQL.execute(db, "PRAGMA foreign_keys=OFF")

      existing =
        run(
          conn,
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          []
        )

      for %{"name" => name} <- existing, not String.starts_with?(name, "message_search_index_") do
        :ok = SQL.execute(db, "DROP TABLE IF EXISTS \"#{name}\"")
      end

      for sql <- fixture["schema"], do: :ok = SQL.execute(db, sql)
      :ok = SQL.execute(db, "BEGIN IMMEDIATE")

      for {table, rows} <- fixture["tables"], row <- rows do
        fields = Map.keys(row)
        names = Enum.map_join(fields, ",", &("\"" <> &1 <> "\""))
        placeholders = Enum.map_join(fields, ",", fn _ -> "?" end)

        run(
          conn,
          "INSERT INTO \"#{table}\" (#{names}) VALUES (#{placeholders})",
          Enum.map(fields, &row[&1])
        )
      end

      :ok = SQL.execute(db, "COMMIT; PRAGMA foreign_keys=ON")
      written([:all])
      :ok
    end)
  end

  defp checkout(pool, timeout, fun) do
    NimblePool.checkout!(pool, :checkout, fn _, conn -> {fun.(conn), :ok} end, timeout)
  end

  defp read?(<<c, rest::binary>>) when c in ~c" \t\r\n", do: read?(rest)

  defp read?(<<s, e, l, e2, c, t, _::binary>>) when s in ~c"Ss" and e in ~c"Ee",
    do: String.upcase(<<s, e, l, e2, c, t>>) == "SELECT"

  # A common table expression in front of a SELECT (this app writes no DML through WITH).
  defp read?(<<w, i, t, h, c, _::binary>>) when w in ~c"Ww" and c in ~c" \t\r\n",
    do: String.upcase(<<w, i, t, h>>) == "WITH"

  defp read?(_), do: false

  @doc false
  def run({db, statements}, sql, params) do
    stmt = statement(db, statements, sql)

    try do
      :ok = SQL.bind(stmt, params)
      {:ok, columns} = SQL.columns(db, stmt)
      {:ok, rows} = SQL.fetch_all(db, stmt)
      Enum.map(rows, &:maps.from_list(:lists.zip(columns, &1)))
    after
      SQL.reset(stmt)
    end
  end

  @max_statements 256

  defp statement(db, statements, sql) do
    case :ets.lookup(statements, sql) do
      [{_, stmt}] ->
        stmt

      [] ->
        {:ok, stmt} = SQL.prepare(db, sql)

        if :ets.info(statements, :size) >= @max_statements do
          for {_, old} <- :ets.tab2list(statements), do: SQL.release(db, old)
          :ets.delete_all_objects(statements)
        end

        :ets.insert(statements, {sql, stmt})
        stmt
    end
  end

  defmodule Connection do
    @moduledoc false
    @behaviour NimblePool
    alias Exqlite.Sqlite3, as: SQL

    # Rails' per-connection settings (SQLite3Adapter#configure_connection) except mmap_size:
    # every reader remaps a memory-mapped database after each commit.
    @pragmas "PRAGMA synchronous=NORMAL; PRAGMA journal_size_limit=67108864; PRAGMA cache_size=2000;"

    # Indexes added to the Rails schema on boot, for new and existing databases alike. Additive
    # only, so the database still works with the Rails image. A room's messages are paged by
    # created_at; with only index_messages_on_room_id each page sorted the room's whole history.
    @additions [
      ~s{CREATE INDEX IF NOT EXISTS "index_messages_on_room_id_and_created_at" ON "messages" ("room_id", "created_at")}
    ]

    def additions, do: @additions

    @impl NimblePool
    def init_worker({role, path} = pool_state) do
      {:ok, open(role, path), pool_state}
    end

    @impl NimblePool
    def handle_checkout(:checkout, _from, conn, pool_state), do: {:ok, conn, conn, pool_state}

    @impl NimblePool
    def handle_checkin(:ok, _from, conn, pool_state), do: {:ok, conn, pool_state}

    @impl NimblePool
    def terminate_worker(_reason, {db, _}, pool_state) do
      SQL.close(db)
      {:ok, pool_state}
    end

    defp open(:writer, path) do
      File.mkdir_p!(Path.dirname(path))
      {:ok, db} = SQL.open(path)
      :ok = SQL.execute(db, "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; " <> @pragmas)
      :ok = SQL.set_busy_timeout(db, 5000)
      conn = {db, :ets.new(:statements, [:set, :public])}
      initialize(conn)
      for sql <- @additions, do: :ok = SQL.execute(db, sql)
      conn
    end

    defp open(:reader, path) do
      {:ok, db} = SQL.open(path, mode: :readonly)
      :ok = SQL.execute(db, @pragmas)
      :ok = SQL.set_busy_timeout(db, 5000)
      {db, :ets.new(:statements, [:set, :public])}
    end

    defp initialize({db, _} = conn) do
      run = &Campfire.DB.run(conn, &1, &2)

      if run.(
           "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
           []
         ) == [] do
        schema = Campfire.Assets.read("compat/database-schema.json") |> Jason.decode!()
        :ok = SQL.execute(db, "BEGIN IMMEDIATE")

        try do
          for sql <- schema["schema"], do: :ok = SQL.execute(db, sql)

          for version <- schema["versions"],
              do: run.("INSERT INTO schema_migrations (version) VALUES (?)", [version])

          now = Campfire.Chat.timestamp()

          for {key, value} <- [
                {"environment", System.get_env("RAILS_ENV", "production")},
                {"schema_sha1", schema["schema_sha1"]}
              ],
              do:
                run.(
                  "INSERT INTO ar_internal_metadata (key,value,created_at,updated_at) VALUES (?,?,?,?)",
                  [key, value, now, now]
                )

          :ok = SQL.execute(db, "COMMIT")
        rescue
          error ->
            SQL.execute(db, "ROLLBACK")
            reraise error, __STACKTRACE__
        end
      end
    end
  end
end
