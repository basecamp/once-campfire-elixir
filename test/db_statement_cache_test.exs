defmodule Campfire.DBStatementCacheTest do
  use ExUnit.Case, async: true
  alias Campfire.DB
  alias Exqlite.Sqlite3, as: SQL

  @by_id "SELECT name FROM items WHERE id=?"

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "campfire-statement-cache-#{System.unique_integer([:positive])}.sqlite3"
      )

    on_exit(fn -> for suffix <- ["", "-wal", "-shm"], do: File.rm(path <> suffix) end)

    # A non-empty schema makes the writer skip fixture initialization.
    {:ok, conn} = SQL.open(path)

    :ok =
      SQL.execute(conn, """
      PRAGMA journal_mode=WAL;
      CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT);
      INSERT INTO items (id, name) VALUES (1, 'one'), (2, 'two'), (3, 'three');
      """)

    :ok = SQL.close(conn)

    writer = start_supervised!(Supervisor.child_spec({DB, path: path, name: nil}, id: :writer))

    reader =
      start_supervised!(
        Supervisor.child_spec(
          {DB, path: path, name: nil, read_only: true, statement_cache_size: 2},
          id: :reader
        )
      )

    %{path: path, writer: writer, reader: reader}
  end

  defp q(pid, sql, params \\ []), do: GenServer.call(pid, {:query, sql, params})
  defp statements(reader), do: :sys.get_state(reader).statements
  defp statement(reader, sql), do: reader |> statements() |> Map.fetch!(sql) |> elem(0)

  defp finalized?(reader, stmt),
    do: match?({:error, _}, SQL.multi_step(:sys.get_state(reader).db, stmt))

  defp checkpoint(writer) do
    [%{"busy" => 0, "log" => log, "checkpointed" => checkpointed}] =
      q(writer, "PRAGMA wal_checkpoint(PASSIVE)")

    {log, checkpointed}
  end

  test "reuses one statement per SQL and binds changed parameter values", %{reader: reader} do
    assert [%{"name" => "one"}] = q(reader, @by_id, [1])
    stmt = statement(reader, @by_id)
    assert [%{"name" => "two"}] = q(reader, @by_id, [2])
    assert [] = q(reader, @by_id, [99])
    assert [%{"name" => "three"}] = q(reader, @by_id, [3])
    assert statement(reader, @by_id) == stmt
  end

  test "a partial bind failure evicts the statement and never reuses old bindings", %{
    reader: reader
  } do
    sql = "SELECT ? AS a, ? AS b"
    assert [%{"a" => 1, "b" => "first"}] = q(reader, sql, [1, "first"])
    stmt = statement(reader, sql)

    # The first parameter binds before the second raises.
    assert {:raise, %DB.CallerException{kind: :error, reason: %ArgumentError{}}} =
             q(reader, sql, ["leaked", {:unsupported}])

    refute Map.has_key?(statements(reader), sql)
    assert finalized?(reader, stmt)

    assert {:raise, %DB.CallerException{reason: %ArgumentError{}}} = q(reader, sql, [2])
    assert [%{"a" => nil, "b" => 3}] = q(reader, sql, [nil, 3])
    assert [%{"a" => 4.5, "b" => nil}] = q(reader, sql, [4.5, nil])
  end

  test "SELECT * follows external schema changes", %{writer: writer, reader: reader} do
    sql = "SELECT * FROM items WHERE id=?"
    assert [%{"id" => 1, "name" => "one"} = row] = q(reader, sql, [1])
    assert map_size(row) == 2

    assert [] = q(writer, "ALTER TABLE items ADD COLUMN color TEXT DEFAULT 'red'")
    assert [%{"id" => 1, "name" => "one", "color" => "red"}] = q(reader, sql, [1])

    assert [] = q(writer, "ALTER TABLE items RENAME COLUMN name TO label")
    assert [%{"label" => "one"} = renamed] = q(reader, sql, [1])
    refute Map.has_key?(renamed, "name")

    assert [] = q(writer, "DROP TABLE items")
    assert {:error, %DB.Error{}} = q(reader, sql, [1])
    refute Map.has_key?(statements(reader), sql)

    assert [] = q(writer, "CREATE TABLE items (id INTEGER PRIMARY KEY, title TEXT)")
    assert [] = q(writer, "INSERT INTO items (id, title) VALUES (1, 'recreated')")
    assert [%{"id" => 1, "title" => "recreated"}] = q(reader, sql, [1])
  end

  test "the cache is bounded and finalizes the least recently used statement", %{
    reader: reader
  } do
    [a, b, c] = for n <- 1..3, do: "SELECT #{n} AS n"
    assert [%{"n" => 1}] = q(reader, a)
    assert [%{"n" => 2}] = q(reader, b)
    evicted = statement(reader, b)
    assert [%{"n" => 1}] = q(reader, a)
    assert [%{"n" => 3}] = q(reader, c)

    assert reader |> statements() |> Map.keys() |> Enum.sort() == Enum.sort([a, c])
    assert finalized?(reader, evicted)
    assert [%{"n" => 2}] = q(reader, b)
    assert map_size(statements(reader)) == 2
  end

  test "no read snapshot is retained after success, mid-step error or eviction", %{
    path: path,
    writer: writer,
    reader: reader
  } do
    write = fn name -> assert [] = q(writer, "UPDATE items SET name=? WHERE id=1", [name]) end

    # Control: an unfinished step holds a snapshot and blocks a full checkpoint.
    {:ok, conn} = SQL.open(path, mode: :readonly)
    write.("before control")
    {:ok, open} = SQL.prepare(conn, "SELECT id FROM items")
    assert {:row, _} = SQL.step(conn, open)
    write.("during control")
    {log, checkpointed} = checkpoint(writer)
    assert checkpointed < log
    :ok = SQL.release(conn, open)
    :ok = SQL.close(conn)

    many = "SELECT a.id FROM items a, items b, items c, items d, items e"
    assert length(q(reader, many)) == 243
    write.("after multi-chunk success")
    assert {log, log} = checkpoint(writer)

    failing = "SELECT CASE WHEN id = 3 THEN json('{bad') ELSE id END AS v FROM items ORDER BY id"
    assert {:error, %DB.Error{}} = q(reader, failing)
    write.("after mid-step error")
    assert {log, log} = checkpoint(writer)

    assert [%{"name" => "after mid-step error"}] = q(reader, @by_id, [1])
    write.("after cached success")
    assert {log, log} = checkpoint(writer)
  end

  test "owners survive expected errors and keep existing semantics", %{
    writer: writer,
    reader: reader
  } do
    assert {:error, %DB.Error{}} = q(reader, "UPDATE items SET name='no'")
    assert {:error, %DB.Error{}} = q(reader, "SELECT * FROM missing_table")
    assert {:error, %DB.Error{}} = q(reader, "SELEC nonsense")
    assert {:error, %DB.Error{}} = q(writer, "SELECT * FROM missing_table")

    assert {:raise, %DB.CallerException{reason: %ArgumentError{}}} =
             q(writer, @by_id, [{:unsupported}])

    assert [%{"x" => 7}] = q(reader, "SELECT :x AS x", %{":x" => 7})
    assert [%{"name" => "one"}] = q(reader, @by_id, [1])
    assert [%{"name" => "one"}] = q(writer, @by_id, [1])
    assert Process.alive?(reader) and Process.alive?(writer)
  end

  test "stopping a reader finalizes its cached statements", %{reader: reader} do
    assert [_] = q(reader, @by_id, [1])
    assert [_] = q(reader, "SELECT 1 AS n")
    %DB.Reader{db: db, statements: cached} = :sys.get_state(reader)
    assert map_size(cached) == 2

    :ok = stop_supervised(:reader)
    for {_, {stmt, _}} <- cached, do: assert({:error, _} = SQL.multi_step(db, stmt))
  end
end
