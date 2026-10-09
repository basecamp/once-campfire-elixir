defmodule Campfire.DBCacheTest do
  use ExUnit.Case, async: false
  import Plug.Test
  alias Campfire.{Auth, DB}
  alias Exqlite.Sqlite3, as: SQL
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  @user 127_326_141
  @name "SELECT name FROM users WHERE id=?"

  setup do
    DB.restore_fixture(@fixture)
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T16:00:00Z")
    on_exit(fn -> System.delete_env("CAMPFIRE_CLOCK") end)
    :ok
  end

  defp generation(table), do: :ets.lookup_element(Campfire.DB.Generations, table, 2, 0)

  test "a cached read is replaced after a write to its table" do
    assert [%{"name" => "David"}] = DB.cached(@name, [@user], ~w(users))
    DB.query("UPDATE users SET name=? WHERE id=?", ["Dave", @user])
    assert [%{"name" => "Dave"}] = DB.cached(@name, [@user], ~w(users))
  end

  test "a transaction's writes invalidate after it commits" do
    assert [%{"name" => "David"}] = DB.cached(@name, [@user], ~w(users))

    DB.transaction(fn q ->
      q.("UPDATE users SET name=? WHERE id=?", ["In a transaction", @user])
    end)

    assert [%{"name" => "In a transaction"}] = DB.cached(@name, [@user], ~w(users))
  end

  test "writes bump only their own table, and a WITH query is a read" do
    users = generation("users")
    rooms = generation("rooms")
    all = generation(:all)

    DB.query("UPDATE rooms SET name=name WHERE id=486777696")
    assert generation("rooms") == rooms + 1
    assert generation("users") == users

    assert [%{"a" => 1}] = DB.query("WITH x AS (SELECT 1 AS a) SELECT a FROM x")
    assert generation(:all) == all
  end

  # A commit by another SQLite client, on its own connection.
  defp foreign(sql) do
    path = String.replace_suffix(:persistent_term.get({DB, :wal_index}), "-shm", "")
    {:ok, db} = SQL.open(path)

    try do
      :ok = SQL.set_busy_timeout(db, 5000)
      :ok = SQL.execute(db, sql)
    after
      SQL.close(db)
    end
  end

  test "another SQLite client's commit invalidates every cached read" do
    assert [%{"name" => "David"}] = DB.cached(@name, [@user], ~w(users))
    foreign("UPDATE users SET name='Outside' WHERE id=#{@user}")
    assert [%{"name" => "Outside"}] = DB.cached(@name, [@user], ~w(users))
  end

  test "a foreign commit is not hidden by an unrelated local write that follows it" do
    assert [%{"name" => "David"}] = DB.cached(@name, [@user], ~w(users))

    # Nothing looks at the database between the foreign commit and a local write to another
    # table, so the local write is the first to see the changed WAL index.
    foreign("UPDATE users SET name='Outside' WHERE id=#{@user}")
    DB.query("UPDATE rooms SET name=name WHERE id=486777696")
    assert [%{"name" => "Outside"}] = DB.cached(@name, [@user], ~w(users))

    foreign("UPDATE users SET name='Outside again' WHERE id=#{@user}")
    DB.transaction(fn q -> q.("UPDATE rooms SET name=name WHERE id=486777696") end)
    assert [%{"name" => "Outside again"}] = DB.cached(@name, [@user], ~w(users))

    # The same inside a request, where the WAL index is checked once per request.
    Process.put(:campfire_request, true)
    Process.delete(:campfire_db_checked)
    assert [%{"name" => "Outside again"}] = DB.cached(@name, [@user], ~w(users))
    foreign("UPDATE users SET name='Outside once more' WHERE id=#{@user}")
    DB.query("UPDATE rooms SET name=name WHERE id=486777696")
    Process.delete(:campfire_db_checked)
    assert [%{"name" => "Outside once more"}] = DB.cached(@name, [@user], ~w(users))
  after
    Process.delete(:campfire_request)
    Process.delete(:campfire_db_checked)
  end

  test "a cached session lookup is rejected once the session is deleted" do
    user = DB.one("SELECT * FROM users WHERE id=?", [@user])
    raw = (conn(:get, "/") |> Auth.start_session(user)).resp_cookies["session_token"][:value]

    lookup = fn ->
      conn(:get, "/") |> put_req_cookie("session_token", raw) |> Auth.session_lookup()
    end

    assert {_, %{"id" => @user}, %{"id" => id}} = lookup.()
    assert {_, %{"id" => @user}, _} = lookup.()
    DB.query("DELETE FROM sessions WHERE id=?", [id])
    assert {_, nil, nil} = lookup.()
  end
end
