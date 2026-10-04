defmodule Campfire.DB do
  @moduledoc """
  SQLite access through pooled connections.

  `SELECT` statements run on a pool of read-only WAL connections; every other
  statement and every transaction runs on the single writer connection, so
  writes stay serialized exactly as with Rails' one-writer SQLite setup.
  Connections are checked out into the calling process and keep a bounded
  cache of prepared statements.
  """
  use Supervisor
  alias Exqlite.Sqlite3, as: SQL

  @writer Campfire.DB.Writer
  @readers Campfire.DB.Readers

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Supervisor
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    readers = Keyword.get(opts, :readers, System.schedulers_online())

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

    checkout(if(read?(sql), do: @readers, else: @writer), 5_000, run_safely)
  end

  def one(sql, params \\ []), do: List.first(query(sql, params))

  def transaction(fun) do
    checkout(@writer, 30_000, fn {db, _} = conn ->
      :ok = SQL.execute(db, "BEGIN IMMEDIATE")

      try do
        result = fun.(fn sql, params -> run(conn, sql, params) end)
        :ok = SQL.execute(db, "COMMIT")
        result
      rescue
        e ->
          SQL.execute(db, "ROLLBACK")
          {:error, e}
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
      :ok
    end)
  end

  defp checkout(pool, timeout, fun) do
    NimblePool.checkout!(pool, :checkout, fn _, conn -> {fun.(conn), :ok} end, timeout)
  end

  defp read?(<<c, rest::binary>>) when c in ~c" \t\r\n", do: read?(rest)

  defp read?(<<s, e, l, e2, c, t, _::binary>>),
    do: String.upcase(<<s, e, l, e2, c, t>>) == "SELECT"

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

    @pragmas "PRAGMA synchronous=NORMAL; PRAGMA cache_size=2000; PRAGMA mmap_size=134217728;"

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
