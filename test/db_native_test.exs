defmodule Campfire.DBNativeTest do
  use ExUnit.Case, async: false
  alias Campfire.DB
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  # The library is only built when Exqlite links the system SQLite (EXQLITE_USE_SYSTEM).
  @moduletag skip: DB.Native.wal_header("") == :unavailable && "campfire_sqlite is not built"

  setup do
    DB.restore_fixture(@fixture)
    {:ok, connection} = DB.Native.open(System.fetch_env!("DATABASE_PATH"))
    {:ok, connection: connection}
  end

  defp pooled(sql, params) do
    NimblePool.checkout!(Campfire.DB.Readers, :checkout, fn _, conn ->
      {DB.run(conn, sql, params), :ok}
    end)
  end

  test "native reads return the same rows as a pooled reader", %{connection: connection} do
    for {sql, params} <- [
          {"SELECT * FROM users ORDER BY id", []},
          {"SELECT * FROM messages WHERE room_id=? ORDER BY created_at DESC LIMIT ?", [1, 5]},
          {"SELECT ? AS a, ? AS b, ? AS c, ? AS d, x'00ff' AS e", [nil, 1.5, "tëxt", -7]},
          {"WITH n(i) AS (SELECT 1) SELECT i FROM n", []},
          {"SELECT id FROM users WHERE id=?", [-1]}
        ] do
      rows = pooled(sql, params)
      assert DB.Native.query(connection, sql, params) == {:ok, rows}
      assert DB.query(sql, params) == rows
    end
  end

  test "native reads refuse what belongs on a pooled reader", %{connection: connection} do
    assert DB.Native.query(connection, "SELECT ?", [true]) == :unsupported
    assert DB.Native.query(connection, "SELECT ?", [{:blob, "x"}]) == :unsupported
    assert DB.Native.query(connection, "SELECT ?", []) == :unsupported
    assert DB.Native.query(connection, "SELECT 1 AS a, 2 AS a", []) == :unsupported
    assert DB.Native.query(connection, "SELECT 1; SELECT 2", []) == :unsupported
    assert DB.Native.query(connection, "DELETE FROM schema_migrations", []) == :unsupported
    assert DB.Native.query(connection, "SELECT nope", []) == :unsupported
    assert DB.one("SELECT 1 AS a, 2 AS a") == %{"a" => 2}
    assert {:error, _} = DB.query("SELECT nope")
  end

  test "native reads see committed writes and a restored schema", %{connection: connection} do
    sql = "SELECT version FROM schema_migrations WHERE version=?"
    assert DB.Native.query(connection, sql, ["native"]) == {:ok, []}
    DB.query("INSERT INTO schema_migrations (version) VALUES (?)", ["native"])
    assert DB.Native.query(connection, sql, ["native"]) == {:ok, [%{"version" => "native"}]}
    assert DB.one(sql, ["native"]) == %{"version" => "native"}
    DB.restore_fixture(@fixture)
    assert DB.Native.query(connection, sql, ["native"]) == {:ok, []}
  end

  test "a statement that runs long is interrupted and handed to a pooled reader",
       %{connection: connection} do
    sql =
      "SELECT * FROM (WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<?) SELECT count(*) AS c FROM n)"

    # Its first run is cut short at the budget (1 ms; the pooled reader takes about 200 ms),
    # and the statement is then refused until the pooled reader has carried it for a while.
    {elapsed, result} = :timer.tc(fn -> DB.Native.query(connection, sql, [3_000_000]) end)
    assert result == :slow
    assert elapsed < 50_000
    assert DB.Native.query(connection, sql, [1]) == :slow
    assert DB.one(sql, [1]) == %{"c" => 1}
    assert DB.one(sql, [3_000_000]) == %{"c" => 3_000_000}

    # A quick statement still runs in full afterwards.
    assert DB.Native.query(connection, "SELECT count(*) AS c FROM users", []) ==
             {:ok, [%{"c" => DB.one("SELECT count(*) AS c FROM users")["c"]}]}
  end

  test "the WAL index header changes with every commit" do
    path = System.fetch_env!("DATABASE_PATH") <> "-shm"
    before = DB.Native.wal_header(path)
    assert byte_size(before) == 48
    assert DB.Native.wal_header(path) == before
    {:ok, file} = :file.open(path, [:read, :raw, :binary])
    assert :file.pread(file, 0, 48) == {:ok, before}
    :file.close(file)
    DB.query("INSERT INTO schema_migrations (version) VALUES (?)", ["wal"])
    after_commit = DB.Native.wal_header(path)
    assert after_commit != before

    # The kept descriptor belongs to a path; another path is read on its own.
    other = Path.join(System.tmp_dir!(), "campfire-native-#{System.unique_integer([:positive])}")
    File.write!(other, :binary.copy(<<7>>, 48))
    assert DB.Native.wal_header(other) == :binary.copy(<<7>>, 48)
    assert DB.Native.wal_header(path) == after_commit
    assert DB.Native.wal_header(other <> ".missing") == nil
    File.rm!(other)
    assert DB.Native.wal_header(other) == nil
  end
end
