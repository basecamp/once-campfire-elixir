defmodule Campfire.DB do
  use GenServer
  alias Exqlite.Sqlite3, as: SQL
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    path = Keyword.fetch!(opts, :path)
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
          raise error
      end
    end
  end

  def query(sql, params \\ []), do: GenServer.call(__MODULE__, {:query, sql, params})
  def one(sql, params \\ []), do: List.first(query(sql, params))
  def transaction(fun), do: GenServer.call(__MODULE__, {:transaction, fun}, 30_000)

  def restore_fixture(fixture),
    do: GenServer.call(__MODULE__, {:restore_fixture, fixture}, 30_000)

  @reads ["select", "with", "pragma", "explai"]
  @doc "Whether `sql` can change data; such statements advance the response cache generation."
  def write?(sql) do
    head =
      sql |> String.trim_leading() |> binary_part(0, min(6, byte_size(sql))) |> String.downcase()

    not Enum.any?(@reads, &String.starts_with?(head, &1))
  end

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
    Campfire.ResponseCache.bump()
    Campfire.ResponseCache.clear()
    {:reply, :ok, db}
  end

  def handle_call({:query, sql, params}, _, db) do
    result =
      try do
        run(db, sql, params)
      rescue
        e -> {:error, e}
      end

    if write?(sql), do: Campfire.ResponseCache.bump()
    {:reply, result, db}
  end

  def handle_call({:transaction, fun}, _, db) do
    :ok = SQL.execute(db, "BEGIN IMMEDIATE")

    try do
      result = fun.(fn sql, params -> run(db, sql, params) end)
      :ok = SQL.execute(db, "COMMIT")
      Campfire.ResponseCache.bump()
      {:reply, result, db}
    rescue
      e ->
        SQL.execute(db, "ROLLBACK")
        {:reply, {:error, e}, db}
    end
  end

  defp run(db, sql, params) do
    {:ok, stmt} = SQL.prepare(db, sql)

    try do
      :ok = SQL.bind(stmt, params)
      {:ok, columns} = SQL.columns(db, stmt)
      {:ok, rows} = SQL.fetch_all(db, stmt)
      Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
    after
      SQL.release(db, stmt)
    end
  end

  def terminate(_, db), do: SQL.close(db)
end
