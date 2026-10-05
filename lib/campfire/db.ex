defmodule Campfire.DB do
  @moduledoc "Pooled SQLite access; bootstrap and fixture restore use a raw connection."
  alias Exqlite.Sqlite3, as: SQL

  @pragmas "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA cache_size=2000; PRAGMA mmap_size=134217728;"

  def child_spec(opts),
    do: %{id: __MODULE__, type: :supervisor, start: {__MODULE__, :start_link, [opts]}}

  # SQLite allows one writer. Writers queue on a single connection in DBConnection
  # rather than in SQLite's busy handler, which would hold dirty IO schedulers.
  def start_link(opts) do
    path = Keyword.fetch!(opts, :path)
    File.mkdir_p!(Path.dirname(path))
    :persistent_term.put({__MODULE__, :path}, path)
    with_raw(path, &initialize/1)

    pool = fn name, size ->
      DBConnection.child_spec(
        Exqlite.Connection,
        name: name,
        pool_size: size,
        database: path,
        foreign_keys: :on,
        journal_mode: :wal,
        synchronous: :normal,
        cache_size: 2000,
        custom_pragmas: [mmap_size: 134_217_728],
        busy_timeout: 5000,
        default_transaction_mode: :immediate,
        # Queue like the former single process instead of shedding load after 50 ms.
        queue_target: 5000,
        queue_interval: 5000
      )
      |> Supervisor.child_spec(id: name)
    end

    Supervisor.start_link(
      [
        pool.(__MODULE__.Write, 1),
        pool.(__MODULE__.Read, Keyword.get(opts, :pool_size, System.schedulers_online()))
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  def query(sql, params \\ []) do
    pool = if String.starts_with?(sql, "SELECT"), do: __MODULE__.Read, else: __MODULE__.Write
    run!(pool, sql, params)
  rescue
    e -> {:error, e}
  end

  def one(sql, params \\ []), do: List.first(query(sql, params))

  def transaction(fun) do
    case DBConnection.transaction(__MODULE__.Write, fn conn ->
           fun.(fn sql, params -> run!(conn, sql, params) end)
         end) do
      {:ok, result} -> result
      error -> error
    end
  rescue
    e -> {:error, e}
  end

  def restore_fixture(fixture) do
    with_raw(:persistent_term.get({__MODULE__, :path}), fn db ->
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
      :ok
    end)
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

  defp with_raw(path, fun) do
    {:ok, db} = SQL.open(path)

    try do
      :ok = SQL.execute(db, @pragmas)
      :ok = SQL.set_busy_timeout(db, 5000)
      fun.(db)
    after
      SQL.close(db)
    end
  end

  defp run!(conn, sql, params) do
    %{columns: columns, rows: rows} = Exqlite.query!(conn, sql, params)
    Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
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
end
