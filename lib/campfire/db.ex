defmodule Campfire.DB do
  @moduledoc """
  SQLite access through `Campfire.SQLite` connections.

  Reads (`SELECT`) outside a transaction run in the caller on one of the
  read-only connections opened at startup, picked at random from a tuple in
  `:persistent_term`. Everything else runs in the caller on the single write
  connection, which this process hands out like a lock: callers check it out,
  run their statements and check it back in. The lock monitors its owner and
  waiters; if the owner exits it rolls back any open transaction before the
  next caller gets the connection.
  """
  use GenServer
  alias Campfire.SQLite

  @connections {__MODULE__, :connections}
  @transaction_db {__MODULE__, :transaction_db}

  defmodule Error do
    defexception [:reason, message: "SQLite operation failed"]
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  ## Public API

  def query(sql, params \\ []) do
    case Process.get(@transaction_db) do
      nil ->
        if select?(sql),
          do: rescue_error(fn -> run(reader(), sql, params) end),
          else: with_writer(fn conn -> rescue_error(fn -> run(conn, sql, params) end) end)

      conn ->
        run(conn, sql, params)
    end
  end

  def one(sql, params \\ []) do
    case query(sql, params) do
      {:error, _} = error -> error
      rows -> List.first(rows)
    end
  end

  def transaction(fun) do
    case Process.get(@transaction_db) do
      nil -> with_writer(&transaction(&1, fun))
      conn -> fun.(fn sql, params -> run(conn, sql, params) end)
    end
  end

  def restore_fixture(fixture), do: with_writer(&restore_fixture(&1, fixture))

  ## Write lock

  defp with_writer(fun) do
    conn = GenServer.call(__MODULE__, :checkout, :infinity)

    try do
      fun.(conn)
    after
      GenServer.cast(__MODULE__, {:checkin, self()})
    end
  end

  @impl true
  def init(opts) do
    path = Keyword.fetch!(opts, :path)
    Process.flag(:trap_exit, true)
    writer = open_writer(path)
    count = Keyword.get(opts, :readers, min(System.schedulers_online(), 8))
    readers = for _ <- 1..count, do: open_reader(path)
    :persistent_term.put(@connections, {writer, List.to_tuple(readers)})
    {:ok, %{writer: writer, readers: readers, owner: nil, waiting: :queue.new()}}
  end

  @impl true
  def handle_call(:checkout, {pid, _} = from, %{owner: nil} = state) do
    {:noreply, grant(state, from, Process.monitor(pid))}
  end

  def handle_call(:checkout, {pid, _} = from, state) do
    {:noreply, %{state | waiting: :queue.in({from, Process.monitor(pid)}, state.waiting)}}
  end

  @impl true
  def handle_cast({:checkin, pid}, %{owner: {pid, ref}} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, next(state)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _}, %{owner: {_, ref}} = state) do
    # The owner may have exited mid-transaction; any statement it was still
    # running finishes first, as the connection serializes its callers.
    if SQLite.transaction?(state.writer), do: SQLite.execute(state.writer, "ROLLBACK")
    {:noreply, next(state)}
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    {:noreply,
     %{state | waiting: :queue.filter(fn {_, waiting} -> waiting != ref end, state.waiting)}}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp grant(state, {pid, _} = from, ref) do
    GenServer.reply(from, state.writer)
    %{state | owner: {pid, ref}}
  end

  defp next(state) do
    case :queue.out(state.waiting) do
      {{:value, {from, ref}}, waiting} -> grant(%{state | waiting: waiting}, from, ref)
      {:empty, _} -> %{state | owner: nil}
    end
  end

  @impl true
  def terminate(_, state) do
    :persistent_term.erase(@connections)
    for conn <- [state.writer | state.readers], do: SQLite.close(conn)
    :ok
  end

  ## Connections

  defp reader do
    {_, readers} = :persistent_term.get(@connections)
    elem(readers, :rand.uniform(tuple_size(readers)) - 1)
  end

  defp open_reader(path) do
    {:ok, conn} = SQLite.open(path, readonly: true)

    :ok =
      SQLite.execute(
        conn,
        "PRAGMA foreign_keys=ON; PRAGMA synchronous=NORMAL; PRAGMA cache_size=-2000;"
      )

    conn
  end

  defp open_writer(path) do
    File.mkdir_p!(Path.dirname(path))
    {:ok, conn} = SQLite.open(path)

    :ok =
      SQLite.execute(
        conn,
        "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA cache_size=2000; PRAGMA mmap_size=134217728;"
      )

    initialize(conn)
    ensure_refresh_index(conn)
    conn
  end

  defp ensure_refresh_index(conn) do
    if run(conn, "SELECT name FROM sqlite_master WHERE type='table' AND name='messages'", []) !=
         [] do
      execute!(
        conn,
        "CREATE INDEX IF NOT EXISTS index_messages_on_room_id_and_updated_at ON messages(room_id,updated_at)"
      )
    end
  end

  defp initialize(conn) do
    if run(
         conn,
         "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
         []
       ) == [] do
      schema = Campfire.Assets.read("compat/database-schema.json") |> Jason.decode!()

      transaction(conn, fn _ ->
        for sql <- schema["schema"], do: execute!(conn, sql)

        for version <- schema["versions"],
            do: run(conn, "INSERT INTO schema_migrations (version) VALUES (?)", [version])

        now = Campfire.Chat.timestamp()

        for {key, value} <- [
              {"environment", System.get_env("RAILS_ENV", "production")},
              {"schema_sha1", schema["schema_sha1"]}
            ],
            do:
              run(
                conn,
                "INSERT INTO ar_internal_metadata (key,value,created_at,updated_at) VALUES (?,?,?,?)",
                [key, value, now, now]
              )
      end)
      |> case do
        {:error, error} -> raise error
        _ -> :ok
      end
    end
  end

  defp restore_fixture(conn, fixture) do
    execute!(conn, "PRAGMA foreign_keys=OFF")

    # Like transaction/2, a failure rolls back so the writer is never handed
    # on inside a transaction, and foreign keys are restored on every exit.
    try do
      existing =
        run(
          conn,
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          []
        )

      for %{"name" => name} <- existing, not String.starts_with?(name, "message_search_index_") do
        execute!(conn, "DROP TABLE IF EXISTS \"#{name}\"")
      end

      for sql <- fixture["schema"], do: execute!(conn, sql)
      execute!(conn, "BEGIN IMMEDIATE")

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

      execute!(conn, "COMMIT")
    rescue
      error ->
        if SQLite.transaction?(conn), do: SQLite.execute(conn, "ROLLBACK")
        reraise error, __STACKTRACE__
    after
      SQLite.execute(conn, "PRAGMA foreign_keys=ON")
    end

    ensure_refresh_index(conn)
    :ok
  end

  # A transaction on a checked-out writer. SQLite errors roll back and are
  # returned; anything else rolls back and is re-raised in the caller.
  defp transaction(conn, fun) do
    execute!(conn, "BEGIN IMMEDIATE")
    Process.put(@transaction_db, conn)

    try do
      result = fun.(fn sql, params -> run(conn, sql, params) end)
      execute!(conn, "COMMIT")
      result
    rescue
      error in Error ->
        SQLite.execute(conn, "ROLLBACK")
        {:error, error}

      error ->
        SQLite.execute(conn, "ROLLBACK")
        reraise error, __STACKTRACE__
    catch
      kind, reason ->
        SQLite.execute(conn, "ROLLBACK")
        :erlang.raise(kind, reason, __STACKTRACE__)
    after
      Process.delete(@transaction_db)
    end
  end

  defp run(conn, sql, params) do
    case SQLite.query(conn, sql, params) do
      {:ok, rows} -> rows
      {:error, reason} -> raise %Error{reason: reason, message: inspect(reason)}
    end
  end

  defp rescue_error(fun) do
    fun.()
  rescue
    error in Error -> {:error, error}
  end

  defp execute!(conn, sql) do
    case SQLite.execute(conn, sql) do
      :ok -> :ok
      {:error, reason} -> raise %Error{reason: reason, message: inspect(reason)}
    end
  end

  defp select?(sql), do: sql |> String.trim_leading() |> String.starts_with?("SELECT")
end
