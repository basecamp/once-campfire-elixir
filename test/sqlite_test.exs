defmodule Campfire.SQLiteTest do
  use ExUnit.Case, async: true
  alias Campfire.SQLite

  @by_id "SELECT name FROM items WHERE id=?"

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "campfire-sqlite-#{System.unique_integer([:positive])}.sqlite3"
      )

    on_exit(fn -> for suffix <- ["", "-wal", "-shm"], do: File.rm(path <> suffix) end)

    {:ok, writer} = SQLite.open(path)

    :ok =
      SQLite.execute(writer, """
      PRAGMA journal_mode=WAL;
      CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT);
      INSERT INTO items (id, name) VALUES (1, 'one'), (2, 'two'), (3, 'three');
      """)

    {:ok, reader} = SQLite.open(path, readonly: true, statements: 2)
    %{path: path, writer: writer, reader: reader}
  end

  defp q(conn, sql, params \\ []) do
    case SQLite.query(conn, sql, params) do
      {:ok, rows} -> rows
      error -> error
    end
  end

  defp checkpoint(writer) do
    [%{"busy" => 0, "log" => log, "checkpointed" => checkpointed}] =
      q(writer, "PRAGMA wal_checkpoint(PASSIVE)")

    {log, checkpointed}
  end

  test "values round trip as stored", %{writer: writer} do
    assert [row] =
             q(writer, "SELECT ? AS i, ? AS f, ? AS t, ? AS b, ? AS n, ? AS a, ? AS l", [
               42,
               4.5,
               "text",
               {:blob, <<0, 1, 2>>},
               nil,
               true,
               ["io", ["list"]]
             ])

    assert row == %{
             "i" => 42,
             "f" => 4.5,
             "t" => "text",
             "b" => <<0, 1, 2>>,
             "n" => nil,
             "a" => "true",
             "l" => "iolist"
           }

    assert [%{"x" => 7}] = q(writer, "SELECT :x AS x", %{":x" => 7})
    assert [] = q(writer, "")
  end

  test "reuses one statement per SQL and binds changed parameter values", %{reader: reader} do
    assert [%{"name" => "one"}] = q(reader, @by_id, [1])
    assert [%{"name" => "two"}] = q(reader, @by_id, [2])
    assert [] = q(reader, @by_id, [99])
    assert [%{"name" => "three"}] = q(reader, @by_id, [3])
    assert SQLite.statements(reader) == [@by_id]
  end

  test "a partial bind failure never leaves bindings behind", %{reader: reader} do
    sql = "SELECT ? AS a, ? AS b"
    assert [%{"a" => 1, "b" => "first"}] = q(reader, sql, [1, "first"])

    assert_raise ArgumentError, "unsupported type: {:unsupported}", fn ->
      q(reader, sql, ["leaked", {:unsupported}])
    end

    assert_raise ArgumentError, "expected 2 arguments, got 1", fn -> q(reader, sql, [2]) end
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
    assert {:error, _} = q(reader, sql, [1])

    assert [] = q(writer, "CREATE TABLE items (id INTEGER PRIMARY KEY, title TEXT)")
    assert [] = q(writer, "INSERT INTO items (id, title) VALUES (1, 'recreated')")
    assert [%{"id" => 1, "title" => "recreated"}] = q(reader, sql, [1])
  end

  test "the cache is bounded and evicts the least recently used statement", %{reader: reader} do
    [a, b, c] = for n <- 1..3, do: "SELECT #{n} AS n"
    assert [%{"n" => 1}] = q(reader, a)
    assert [%{"n" => 2}] = q(reader, b)
    assert [%{"n" => 1}] = q(reader, a)
    assert [%{"n" => 3}] = q(reader, c)
    assert SQLite.statements(reader) == [a, c]
    assert [%{"n" => 2}] = q(reader, b)
    assert SQLite.statements(reader) == [c, b]
  end

  test "no read snapshot is retained after success, mid-step error or eviction", %{
    writer: writer,
    reader: reader
  } do
    write = fn name -> assert [] = q(writer, "UPDATE items SET name=? WHERE id=1", [name]) end

    many = "SELECT a.id FROM items a, items b, items c, items d, items e"
    assert length(q(reader, many)) == 243
    write.("after multi-row success")
    assert {log, log} = checkpoint(writer)

    failing = "SELECT CASE WHEN id = 3 THEN json('{bad') ELSE id END AS v FROM items ORDER BY id"
    assert {:error, _} = q(reader, failing)
    write.("after mid-step error")
    assert {log, log} = checkpoint(writer)

    assert [%{"name" => "after mid-step error"}] = q(reader, @by_id, [1])
    write.("after cached success")
    assert {log, log} = checkpoint(writer)
  end

  test "errors are returned and leave the connection usable", %{reader: reader} do
    assert {:error, "attempt to write a readonly database"} =
             q(reader, "UPDATE items SET name='no'")

    assert {:error, "no such table: missing_table"} = q(reader, "SELECT * FROM missing_table")
    assert {:error, _} = q(reader, "SELEC nonsense")
    assert {:error, _} = SQLite.execute(reader, "CREATE TABLE nope (id)")
    assert [%{"name" => "one"}] = q(reader, @by_id, [1])
  end

  test "duplicate column names keep the last value, like Map.new/1", %{reader: reader} do
    assert [%{"x" => 2}] = q(reader, "SELECT 1 AS x, 2 AS x")
  end

  test "concurrent callers share a connection safely", %{reader: reader} do
    1..200
    |> Task.async_stream(fn i -> q(reader, "SELECT ? AS i", [i]) end, max_concurrency: 16)
    |> Enum.with_index(1)
    |> Enum.each(fn {{:ok, rows}, i} -> assert rows == [%{"i" => i}] end)
  end

  test "closing finalizes statements and later calls return errors", %{reader: reader} do
    assert [_] = q(reader, @by_id, [1])
    assert :ok = SQLite.close(reader)
    assert SQLite.statements(reader) == []
    assert {:error, "connection closed"} = q(reader, @by_id, [1])
    assert :ok = SQLite.close(reader)
  end
end
