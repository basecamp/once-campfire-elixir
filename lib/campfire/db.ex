defmodule Campfire.DB do
  use GenServer
  alias Exqlite.Sqlite3, as: SQL
  @transaction_db {__MODULE__, :transaction_db}

  defmodule Error do
    defexception [:reason, message: "SQLite operation failed"]
  end

  defmodule CallerException do
    @moduledoc false
    defstruct [:kind, :reason, :stacktrace]
  end

  defmodule Reader do
    @moduledoc false
    # Readonly connection plus the prepared statements it owns. A cached statement is
    # always idle: multi_step resets it at DONE/BUSY/error and any other failure
    # releases it, so no cached statement holds a WAL read snapshot.
    defstruct [:db, :limit, statements: %{}, uses: 0]
  end

  @statement_cache_size 64

  def start_link(opts) do
    server_opts =
      case Keyword.get(opts, :name, __MODULE__) do
        nil -> []
        name -> [name: name]
      end

    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    if Keyword.get(opts, :read_only, false), do: init_reader(path, opts), else: init_writer(path)
  end

  defp init_reader(path, opts) do
    limit = Keyword.get(opts, :statement_cache_size, @statement_cache_size)
    true = is_integer(limit) and limit > 0

    {:ok, db} = SQL.open(path, mode: :readonly)

    :ok =
      SQL.execute(
        db,
        "PRAGMA foreign_keys=ON; PRAGMA synchronous=NORMAL; PRAGMA cache_size=-2000;"
      )

    :ok = SQL.set_busy_timeout(db, 5000)
    # Supervisor shutdown then runs terminate/2, which finalizes cached statements.
    Process.flag(:trap_exit, true)
    {:ok, %Reader{db: db, limit: limit}}
  end

  defp init_writer(path) do
    File.mkdir_p!(Path.dirname(path))
    {:ok, db} = SQL.open(path)

    :ok =
      SQL.execute(
        db,
        "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA cache_size=2000; PRAGMA mmap_size=134217728;"
      )

    :ok = SQL.set_busy_timeout(db, 5000)
    initialize(db)
    {:ok, db}
  end

  defp initialize(db) do
    if run(
         db,
         "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
         []
       ) == [] do
      schema = Campfire.Assets.read("compat/database-schema.json") |> Jason.decode!()
      :ok = SQL.execute(db, "BEGIN IMMEDIATE")

      try do
        for sql <- schema["schema"], do: :ok = SQL.execute(db, sql)

        for version <- schema["versions"],
            do: run(db, "INSERT INTO schema_migrations (version) VALUES (?)", [version])

        now = Campfire.Chat.timestamp()

        for {key, value} <- [
              {"environment", System.get_env("RAILS_ENV", "production")},
              {"schema_sha1", schema["schema_sha1"]}
            ],
            do:
              run(
                db,
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

  def query(sql, params \\ []) do
    case Process.get(@transaction_db) do
      nil -> query_outside_transaction(sql, params)
      db -> run(db, sql, params)
    end
  end

  def one(sql, params \\ []) do
    case query(sql, params) do
      {:error, _} = error -> error
      rows -> List.first(rows)
    end
  end

  def transaction(fun) do
    case GenServer.call(__MODULE__, {:transaction, fun}, 30_000) do
      {:raise, %CallerException{kind: kind, reason: reason, stacktrace: stacktrace}} ->
        :erlang.raise(kind, reason, stacktrace)

      {:ok, result} ->
        result
    end
  end

  def restore_fixture(fixture),
    do: GenServer.call(__MODULE__, {:restore_fixture, fixture}, 30_000)

  def handle_call({:restore_fixture, fixture}, _, db) do
    :ok = SQL.execute(db, "PRAGMA foreign_keys=OFF")

    existing =
      run(
        db,
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
        db,
        "INSERT INTO \"#{table}\" (#{names}) VALUES (#{placeholders})",
        Enum.map(fields, &row[&1])
      )
    end

    :ok = SQL.execute(db, "COMMIT; PRAGMA foreign_keys=ON")
    {:reply, :ok, db}
  end

  def handle_call({:query, sql, params}, _, %Reader{} = reader) when is_list(params) do
    {cached, statements} = Map.pop(reader.statements, sql)
    reader = %{reader | statements: statements}

    try do
      stmt =
        case cached do
          {stmt, _} -> stmt
          nil -> SQL.prepare(reader.db, sql) |> value!()
        end

      rows = read(reader.db, stmt, params)
      {:reply, rows, cache(reader, sql, stmt)}
    rescue
      error in Error ->
        {:reply, {:error, error}, reader}

      error ->
        {:reply,
         {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}},
         reader}
    end
  end

  def handle_call({:query, sql, params}, from, %Reader{db: db} = reader) do
    {:reply, result, ^db} = handle_call({:query, sql, params}, from, db)
    {:reply, result, reader}
  end

  def handle_call({:query, sql, params}, _, db) do
    result =
      try do
        run(db, sql, params)
      rescue
        error in Error ->
          {:error, error}

        error ->
          {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}}
      end

    {:reply, result, db}
  end

  def handle_call({:transaction, fun}, _, db) do
    try do
      execute!(db, "BEGIN IMMEDIATE")
      result = with_transaction_db(db, fn -> fun.(fn sql, params -> run(db, sql, params) end) end)
      execute!(db, "COMMIT")
      {:reply, {:ok, result}, db}
    rescue
      error in Error ->
        SQL.execute(db, "ROLLBACK")
        {:reply, {:ok, {:error, error}}, db}

      error ->
        SQL.execute(db, "ROLLBACK")

        {:reply,
         {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}}, db}
    catch
      kind, reason ->
        SQL.execute(db, "ROLLBACK")

        {:reply,
         {:raise, %CallerException{kind: kind, reason: reason, stacktrace: __STACKTRACE__}}, db}
    end
  end

  defp query_outside_transaction(sql, params) do
    result =
      if select?(sql) and Process.whereis(Campfire.DB.ReadPool) do
        GenServer.call(
          {:via, PartitionSupervisor, {Campfire.DB.ReadPool, self()}},
          {:query, sql, params},
          15_000
        )
      else
        GenServer.call(__MODULE__, {:query, sql, params})
      end

    case result do
      {:raise, %CallerException{kind: kind, reason: reason, stacktrace: stacktrace}} ->
        :erlang.raise(kind, reason, stacktrace)

      result ->
        result
    end
  end

  defp with_transaction_db(db, fun) do
    Process.put(@transaction_db, db)

    try do
      fun.()
    after
      Process.delete(@transaction_db)
    end
  end

  defp run(db, sql, params) do
    stmt = SQL.prepare(db, sql) |> value!()

    try do
      SQL.bind(stmt, params) |> ok!()
      columns = SQL.columns(db, stmt) |> value!()
      rows = SQL.fetch_all(db, stmt) |> value!()
      Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
    after
      SQL.release(db, stmt)
    end
  end

  # Every parameter is rebound on each use (Sqlite3.bind/2 requires the full positional
  # count), and columns are read after stepping, so an automatic re-prepare after a
  # schema change cannot leave stale names. Any failure finalizes the statement, which
  # also ends a read transaction left open by an incomplete step.
  defp read(db, stmt, params) do
    SQL.bind(stmt, params) |> ok!()
    rows = SQL.fetch_all(db, stmt) |> value!()
    columns = if rows == [], do: [], else: SQL.columns(db, stmt) |> value!()
    Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
  rescue
    error ->
      SQL.release(db, stmt)
      reraise error, __STACKTRACE__
  end

  defp cache(%Reader{statements: statements, limit: limit} = reader, sql, stmt)
       when map_size(statements) >= limit do
    {lru, {evicted, _}} = Enum.min_by(statements, fn {_, {_, used}} -> used end)
    SQL.release(reader.db, evicted)
    cache(%{reader | statements: Map.delete(statements, lru)}, sql, stmt)
  end

  defp cache(%Reader{statements: statements, uses: uses} = reader, sql, stmt) do
    %{reader | statements: Map.put(statements, sql, {stmt, uses + 1}), uses: uses + 1}
  end

  defp select?(sql), do: sql |> String.trim_leading() |> String.starts_with?("SELECT")

  defp execute!(db, sql), do: SQL.execute(db, sql) |> ok!()
  defp ok!(:ok), do: :ok
  defp ok!({:error, reason}), do: sqlite_error!(reason)
  defp value!({:ok, value}), do: value
  defp value!({:error, reason}), do: sqlite_error!(reason)

  defp sqlite_error(reason), do: %Error{reason: reason, message: inspect(reason)}

  defp sqlite_error!(reason), do: raise(sqlite_error(reason))

  def terminate(_, %Reader{db: db, statements: statements}) do
    for {_, {stmt, _}} <- statements, do: SQL.release(db, stmt)
    SQL.close(db)
  end

  def terminate(_, db), do: SQL.close(db)
end
