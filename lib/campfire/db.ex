defmodule Campfire.DB do
  use GenServer
  alias Exqlite.Sqlite3, as: SQL
  @transaction_db {__MODULE__, :transaction_db}
  @data_version_sql "PRAGMA data_version"

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

  defmodule Writer do
    @moduledoc false
    # A writable connection plus the prepared statements it owns. The statements live in a private
    # ETS table rather than in the GenServer state so the transaction closures below share them
    # without threading state through the caller's callback.
    defstruct [:db, :statements]
  end

  @statement_cache_size 64
  @writer_statement_cache_size 128

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

    # cache_size 2000 pages matches the captured reference pragma (vectors/database-pragmas.json)
    # and measured about 9% faster than the 2 MiB it replaced. mmap_size is deliberately absent: on
    # these small indexed reads it measured 17% slower (8.74 -> 10.27 us).
    :ok =
      SQL.execute(
        db,
        "PRAGMA foreign_keys=ON; PRAGMA synchronous=NORMAL; PRAGMA cache_size=2000;"
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

    ensure_refresh_index(db)
    {:ok, %Writer{db: db, statements: :ets.new(:campfire_writer_statements, [:set, :private])}}
  end

  defp ensure_refresh_index(db) do
    if run_raw(db, "SELECT name FROM sqlite_master WHERE type='table' AND name='messages'", []) !=
         [] do
      :ok =
        SQL.execute(
          db,
          "CREATE INDEX IF NOT EXISTS index_messages_on_room_id_and_updated_at ON messages(room_id,updated_at)"
        )
    end
  end

  defp initialize(db) do
    if run_raw(
         db,
         "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
         []
       ) == [] do
      schema = Campfire.JSON.decode!(Campfire.Assets.read("compat/database-schema.json"))
      :ok = SQL.execute(db, "BEGIN IMMEDIATE")

      try do
        for sql <- schema["schema"], do: :ok = SQL.execute(db, sql)

        for version <- schema["versions"],
            do: run_raw(db, "INSERT INTO schema_migrations (version) VALUES (?)", [version])

        now = Campfire.Chat.timestamp()

        for {key, value} <- [
              {"environment", Campfire.Env.get("RAILS_ENV", "production")},
              {"schema_sha1", schema["schema_sha1"]}
            ],
            do:
              run_raw(
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
    result =
      case Process.get(@transaction_db) do
        nil -> query_outside_transaction(sql, params)
        writer -> run(writer, sql, params)
      end

    if not select?(sql) do
      bump_write_epoch()
      Campfire.ResponseCache.forget_version()
    end

    result
  end

  def one(sql, params \\ []) do
    case query(sql, params) do
      {:error, _} = error -> error
      rows -> List.first(rows)
    end
  end

  @doc """
  Runs a list of `{sql, params}` on one connection inside a single read transaction and returns one
  result list per statement.

  A page's statements share one snapshot this way, and pay one read transaction instead of one per
  statement. Inside a transaction the statements join that transaction instead.
  """
  def read_batch(statements) when is_list(statements) do
    result =
      case Process.get(@transaction_db) do
        nil ->
          if Process.whereis(Campfire.DB.ReadPool) do
            GenServer.call(
              {:via, PartitionSupervisor, {Campfire.DB.ReadPool, self()}},
              {:read_batch, statements},
              15_000
            )
          else
            GenServer.call(__MODULE__, {:read_batch, statements})
          end

        writer ->
          Enum.map(statements, fn {sql, params} -> run(writer, sql, params) end)
      end

    case result do
      {:raise, %CallerException{kind: kind, reason: reason, stacktrace: stacktrace}} ->
        :erlang.raise(kind, reason, stacktrace)

      {:error, %Error{} = error} ->
        raise error

      result ->
        result
    end
  end

  def transaction(fun) do
    Campfire.ResponseCache.forget_version()

    case GenServer.call(__MODULE__, {:transaction, fun}, 30_000) do
      {:raise, %CallerException{kind: kind, reason: reason, stacktrace: stacktrace}} ->
        :erlang.raise(kind, reason, stacktrace)

      {:ok, result} ->
        result
    end
  end

  def restore_fixture(fixture),
    do: GenServer.call(__MODULE__, {:restore_fixture, fixture}, 30_000)

  def handle_call({:restore_fixture, fixture}, _, %Writer{db: db} = writer) do
    clear_statements(writer)
    :ok = SQL.execute(db, "PRAGMA foreign_keys=OFF")

    existing =
      run_raw(
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

      run_raw(
        db,
        "INSERT INTO \"#{table}\" (#{names}) VALUES (#{placeholders})",
        Enum.map(fields, &row[&1])
      )
    end

    :ok = SQL.execute(db, "COMMIT; PRAGMA foreign_keys=ON")
    ensure_refresh_index(db)
    {:reply, :ok, writer}
  end

  def handle_call({:query, sql, params}, _, %Reader{} = reader) when is_list(params) do
    {cached, statements} = Map.pop(reader.statements, sql)
    reader = %{reader | statements: statements}

    try do
      {rows, reader} = cached_read(reader, cached, sql, params)
      {:reply, rows, reader}
    rescue
      error in Error ->
        {:reply, {:error, error}, reader}

      error ->
        {:reply,
         {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}},
         reader}
    end
  end

  def handle_call({:read_batch, statements}, _, %Reader{} = reader) do
    execute!(reader.db, "BEGIN")

    result =
      Enum.reduce_while(statements, {:ok, [], reader}, fn {sql, params}, {:ok, rows, reader} ->
        {cached, statements} = Map.pop(reader.statements, sql)
        reader = %{reader | statements: statements}

        try do
          {result, reader} = cached_read(reader, cached, sql, params)
          {:cont, {:ok, [result | rows], reader}}
        rescue
          error in Error ->
            {:halt, {:error, error, reader}}

          error ->
            {:halt,
             {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__},
              reader}}
        end
      end)

    case result do
      {:ok, rows, reader} ->
        execute!(reader.db, "COMMIT")
        {:reply, Enum.reverse(rows), reader}

      {kind, payload, reader} ->
        SQL.execute(reader.db, "ROLLBACK")
        {:reply, {kind, payload}, reader}
    end
  end

  def handle_call({:query, sql, params}, from, %Reader{db: db} = reader) do
    {:reply, result, ^db} = handle_call({:query, sql, params}, from, db)
    {:reply, result, reader}
  end

  def handle_call({:query, sql, params}, _, %Writer{} = writer) do
    result =
      try do
        run(writer, sql, params)
      rescue
        error in Error ->
          {:error, error}

        error ->
          {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}}
      end

    {:reply, result, writer}
  end

  # Named parameters take the uncached path, and this is also where a reader's named-parameter
  # clause lands: the statement belongs to that one call.
  def handle_call({:query, sql, params}, _, db) do
    result =
      try do
        run_raw(db, sql, params)
      rescue
        error in Error ->
          {:error, error}

        error ->
          {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}}
      end

    {:reply, result, db}
  end

  def handle_call(:data_version, _, %Reader{} = reader) do
    {cached, statements} = Map.pop(reader.statements, @data_version_sql)
    reader = %{reader | statements: statements}

    try do
      {rows, reader} = cached_read(reader, cached, @data_version_sql, [])
      version = Enum.find_value(rows, &(&1 |> Map.values() |> List.first()))
      answer_waiting_versions(version)
      {:reply, version, reader}
    rescue
      error in Error -> {:reply, {:error, error}, reader}
    end
  end

  def handle_call(:data_version, _, %Writer{} = writer) do
    case run(writer, @data_version_sql, []) do
      [row | _] ->
        version = Map.values(row) |> List.first()
        answer_waiting_versions(version)
        {:reply, version, writer}

      _ ->
        {:reply, nil, writer}
    end
  rescue
    error in Error -> {:reply, {:error, error}, writer}
  end

  def handle_call({:read_batch, statements}, _, %Writer{db: db} = writer) do
    result =
      try do
        execute!(db, "BEGIN")
        rows = Enum.map(statements, fn {sql, params} -> run(writer, sql, params) end)
        execute!(db, "COMMIT")
        rows
      rescue
        error in Error ->
          SQL.execute(db, "ROLLBACK")
          {:error, error}

        error ->
          SQL.execute(db, "ROLLBACK")
          {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}}
      end

    {:reply, result, writer}
  end

  def handle_call({:transaction, fun}, _, %Writer{db: db} = writer) do
    try do
      execute!(db, "BEGIN IMMEDIATE")

      result =
        with_transaction_db(writer, fn -> fun.(fn sql, params -> run(writer, sql, params) end) end)

      execute!(db, "COMMIT")
      {:reply, {:ok, result}, writer}
    rescue
      error in Error ->
        SQL.execute(db, "ROLLBACK")
        {:reply, {:ok, {:error, error}}, writer}

      error ->
        SQL.execute(db, "ROLLBACK")

        {:reply,
         {:raise, %CallerException{kind: :error, reason: error, stacktrace: __STACKTRACE__}},
         writer}
    catch
      kind, reason ->
        SQL.execute(db, "ROLLBACK")

        {:reply,
         {:raise, %CallerException{kind: kind, reason: reason, stacktrace: __STACKTRACE__}},
         writer}
    end
  end

  @doc """
  Reads the version the database is at, once per request.

  A cached version was tried: it read a lock-free cell refreshed every couple of milliseconds. It
  bought 26% at one client and 2.5% at sixty-four, and it left a window in which another writer's
  commit did not invalidate anything - the same criticism reviewers raised against two earlier cache
  branches. Observing it per request keeps external writes visible immediately.
  """
  def data_version, do: read_data_version()

  defp read_data_version do
    result =
      if Process.whereis(Campfire.DB.ReadPool) do
        GenServer.call(
          {:via, PartitionSupervisor, {Campfire.DB.ReadPool, self()}},
          :data_version,
          15_000
        )
      else
        GenServer.call(__MODULE__, :data_version)
      end

    case result do
      version when is_integer(version) -> version
      _ -> nil
    end
  end

  @doc "Increments on every write so caches invalidate without waiting for the version TTL."
  def write_epoch do
    case :persistent_term.get({__MODULE__, :write_epoch}, nil) do
      nil ->
        counter = :atomics.new(1, signed: true)
        :persistent_term.put({__MODULE__, :write_epoch}, counter)
        :atomics.get(counter, 1)

      counter ->
        :atomics.get(counter, 1)
    end
  end

  defp bump_write_epoch do
    counter =
      case :persistent_term.get({__MODULE__, :write_epoch}, nil) do
        nil ->
          counter = :atomics.new(1, signed: true)
          :persistent_term.put({__MODULE__, :write_epoch}, counter)
          counter

        counter ->
          counter
      end

    :atomics.add(counter, 1, 1)
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

  defp with_transaction_db(writer, fun) do
    Process.put(@transaction_db, writer)

    try do
      fun.()
    after
      Process.delete(@transaction_db)
    end
  end

  # The popped cache entry is passed in, so a failure keeps the statement out of the cache and the
  # caller replies with the reader that no longer holds it.
  defp cached_read(%Reader{db: db} = reader, cached, sql, params) do
    stmt =
      case cached do
        {stmt, _} -> stmt
        nil -> SQL.prepare(db, sql) |> value!()
      end

    {read(db, stmt, params), cache(reader, sql, stmt)}
  end

  # Statements the writer keeps are prepared once and rebound per use, the same way the readers'
  # are: an error drops the statement so the next use prepares against whatever the schema is then.
  defp run(%Writer{db: db, statements: statements} = writer, sql, params) do
    stmt = statement(writer, sql)

    try do
      SQL.bind(stmt, params) |> ok!()
      rows = SQL.fetch_all(db, stmt) |> value!()
      columns = if rows == [], do: [], else: SQL.columns(db, stmt) |> value!()
      Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
    rescue
      error ->
        :ets.delete(statements, sql)
        SQL.release(db, stmt)
        reraise error, __STACKTRACE__
    end
  end

  defp statement(%Writer{db: db, statements: statements}, sql) do
    case :ets.lookup(statements, sql) do
      [{^sql, stmt}] ->
        stmt

      [] ->
        stmt = SQL.prepare(db, sql) |> value!()
        evict(db, statements)
        true = :ets.insert(statements, {sql, stmt})
        stmt
    end
  end

  defp evict(db, statements) do
    if :ets.info(statements, :size) >= @writer_statement_cache_size do
      case :ets.first(statements) do
        :"$end_of_table" ->
          :ok

        sql ->
          [{^sql, stmt}] = :ets.lookup(statements, sql)
          SQL.release(db, stmt)
          :ets.delete(statements, sql)
      end
    end
  end

  defp clear_statements(%Writer{db: db, statements: statements}) do
    for {_sql, stmt} <- :ets.tab2list(statements), do: SQL.release(db, stmt)
    :ets.delete_all_objects(statements)
    :ok
  end

  defp run_raw(db, sql, params) do
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

  def terminate(_, %Writer{db: db} = writer) do
    clear_statements(writer)
    SQL.close(db)
  end

  # Every caller in the mailbox asked the same question in the same instant. Answering them from one
  # read collapses the queue instead of paying a statement and a wakeup per request. A caller that
  # gets a slightly older version is the safe direction: its entry lands under an older epoch and the
  # next request, which sees the newer one, misses rather than serves something stale.
  defp answer_waiting_versions(version) do
    receive do
      {:"$gen_call", from, :data_version} ->
        GenServer.reply(from, version)
        answer_waiting_versions(version)
    after
      0 -> :ok
    end
  end
end
