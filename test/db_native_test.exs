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

  test "statements that ran long are handed to a pooled reader", %{connection: connection} do
    sql =
      "SELECT * FROM (WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<?) SELECT count(*) AS c FROM n)"

    assert DB.Native.query(connection, sql, [3_000_000]) == {:ok, [%{"c" => 3_000_000}]}
    assert DB.Native.query(connection, sql, [1]) == :slow
    assert DB.one(sql, [1]) == %{"c" => 1}
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
    assert DB.Native.wal_header(path) != before
  end
end
