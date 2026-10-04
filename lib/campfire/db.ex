defmodule Campfire.DB do
  @moduledoc """
  SQLite access with one writer and pooled readers.

  The writer process owns transactions and every statement that changes data, so writes
  stay serialized exactly as before. Reads are spread round-robin over several reader
  processes, each with its own connection; WAL mode lets them proceed while the writer
  commits, and a busy reader's mailbox queues requests without spinning. Every
  connection caches its prepared statements.
  """
  use GenServer
  alias Exqlite.Sqlite3, as: SQL
  @readers {__MODULE__, :readers}
  @pragmas "PRAGMA foreign_keys=ON; PRAGMA synchronous=NORMAL; PRAGMA cache_size=2000; PRAGMA mmap_size=134217728;"
  @reads ["select", "with", "pragma", "explai"]

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    File.mkdir_p!(Path.dirname(path))
    {:ok, db} = SQL.open(path)
    :ok = SQL.execute(db, "PRAGMA journal_mode=WAL; " <> @pragmas)
    :ok = SQL.set_busy_timeout(db, 5000)
    state = %{db: db, statements: %{}}
    initialize(state)

    readers =
      for _ <- 1..max(8, 2 * System.schedulers_online()) do
        {:ok, pid} = GenServer.start_link(__MODULE__.Reader, path)
        pid
      end

    :persistent_term.put(@readers, {List.to_tuple(readers), :atomics.new(1, signed: false)})
    {:ok, state}
  end

  def pragmas, do: @pragmas

  defp initialize(state) do
    db = state.db

    if run(
         state,
         "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
         []
       ) == [] do
      schema = Campfire.Assets.read("compat/database-schema.json") |> Jason.decode!()
      :ok = SQL.execute(db, "BEGIN IMMEDIATE")

      try do
        for sql <- schema["schema"], do: :ok = SQL.execute(db, sql)

        for version <- schema["versions"],
            do: run(state, "INSERT INTO schema_migrations (version) VALUES (?)", [version])

        now = Campfire.Chat.timestamp()

        for {key, value} <- [
              {"environment", System.get_env("RAILS_ENV", "production")},
              {"schema_sha1", schema["schema_sha1"]}
            ],
            do:
              run(
                state,
                "INSERT INTO ar_internal_metadata (key,value,created_at,updated_at) VALUES (?,?,?,?)",
                [key, value, now, now]
              )

        :ok = SQL.execute(db, "COMMIT")
      rescue
        error ->
          SQL.execute(db, "ROLLBACK")
          raise error
      end
    end
  end

  def query(sql, params \\ []) do
    if write?(sql),
      do: GenServer.call(__MODULE__, {:query, sql, params}),
      else: GenServer.call(reader(), {:query, sql, params})
  end

  def one(sql, params \\ []), do: List.first(query(sql, params))
  def transaction(fun), do: GenServer.call(__MODULE__, {:transaction, fun}, 30_000)

  def restore_fixture(fixture),
    do: GenServer.call(__MODULE__, {:restore_fixture, fixture}, 30_000)

  @doc "Whether `sql` can change data; such statements advance the response cache generation."
  def write?(sql) do
    head =
      sql |> String.trim_leading() |> binary_part(0, min(6, byte_size(sql))) |> String.downcase()

    not Enum.any?(@reads, &String.starts_with?(head, &1))
  end

  defp reader do
    {readers, counter} = :persistent_term.get(@readers)
    elem(readers, rem(:atomics.add_get(counter, 1, 1), tuple_size(readers)))
  end

  defp flush_readers do
    {readers, _} = :persistent_term.get(@readers)
    for pid <- Tuple.to_list(readers), do: GenServer.call(pid, :flush)
    :ok
  end

  def handle_call({:restore_fixture, fixture}, _, %{db: db} = state) do
    :ok = SQL.execute(db, "PRAGMA foreign_keys=OFF")

    existing =
      run(
        state,
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
        state,
        "INSERT INTO \"#{table}\" (#{names}) VALUES (#{placeholders})",
        Enum.map(fields, &row[&1])
      )
    end

    :ok = SQL.execute(db, "COMMIT; PRAGMA foreign_keys=ON")
    flush_readers()
    Campfire.ResponseCache.bump()
    Campfire.ResponseCache.clear()
    {:reply, :ok, %{state | statements: %{}}}
  end

  def handle_call({:query, sql, params}, _, state) do
    {result, state} = guarded(state, sql, params)
    if write?(sql), do: Campfire.ResponseCache.bump()
    {:reply, result, state}
  end

  def handle_call({:transaction, fun}, _, %{db: db} = state) do
    :ok = SQL.execute(db, "BEGIN IMMEDIATE")

    try do
      result = fun.(fn sql, params -> run(state, sql, params) end)
      :ok = SQL.execute(db, "COMMIT")
      Campfire.ResponseCache.bump()
      {:reply, result, state}
    rescue
      e ->
        SQL.execute(db, "ROLLBACK")
        {:reply, {:error, e}, state}
    end
  end

  @doc false
  def guarded(state, sql, params) do
    {statements, stmt} = statement(state, sql)
    state = %{state | statements: statements}
    {execute(state.db, stmt, params), state}
  rescue
    e -> {{:error, e}, state}
  end

  # Statements used inside the writer's transactions are cached only for the transaction.
  defp run(state, sql, params) do
    {_, stmt} = statement(state, sql)
    execute(state.db, stmt, params)
  end

  defp statement(%{db: db, statements: statements}, sql) do
    case statements do
      %{^sql => stmt} ->
        {statements, stmt}

      _ ->
        {:ok, stmt} = SQL.prepare(db, sql)
        statements = if map_size(statements) >= 1024, do: %{}, else: statements
        {Map.put(statements, sql, stmt), stmt}
    end
  end

  defp execute(db, stmt, params) do
    :ok = SQL.reset(stmt)
    :ok = SQL.bind(stmt, params)
    {:ok, columns} = SQL.columns(db, stmt)
    {:ok, rows} = SQL.fetch_all(db, stmt)
    Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
  end

  def terminate(_, %{db: db}), do: SQL.close(db)

  defmodule Reader do
    @moduledoc false
    use GenServer
    alias Exqlite.Sqlite3, as: SQL

    def init(path) do
      {:ok, db} = SQL.open(path)
      :ok = SQL.execute(db, Campfire.DB.pragmas())
      :ok = SQL.set_busy_timeout(db, 5000)
      {:ok, %{db: db, statements: %{}}}
    end

    def handle_call({:query, sql, params}, _, state) do
      {result, state} = Campfire.DB.guarded(state, sql, params)
      {:reply, result, state}
    end

    def handle_call(:flush, _, state), do: {:reply, :ok, %{state | statements: %{}}}
    def terminate(_, %{db: db}), do: SQL.close(db)
  end
end
