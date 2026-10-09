defmodule Campfire.DBTest do
  use ExUnit.Case, async: false
  alias Campfire.{DB, SQLite}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    :ok = DB.restore_fixture(@fixture)
  end

  defp readers do
    {_writer, readers} = :persistent_term.get({DB, :connections})
    Tuple.to_list(readers)
  end

  defp hold_transaction(id, name) do
    parent = self()

    task =
      Task.async(fn ->
        DB.transaction(fn query ->
          query.("UPDATE accounts SET name=? WHERE id=?", [name, id])
          send(parent, :writer_started)

          receive do
            :release_writer -> :ok
          after
            5_000 -> raise "writer was not released"
          end
        end)
      end)

    assert_receive :writer_started
    task
  end

  test "reads use the readers while the writer is busy" do
    %{"id" => id, "name" => original} = DB.one("SELECT id, name FROM accounts LIMIT 1")
    writer = hold_transaction(id, "committed later")

    reader = Task.async(fn -> DB.one("SELECT name FROM accounts WHERE id=?", [id]) end)
    assert {:ok, %{"name" => ^original}} = Task.yield(reader, 1_000)

    send(writer.pid, :release_writer)
    assert :ok = Task.await(writer)
    assert %{"name" => "committed later"} = DB.one("SELECT name FROM accounts WHERE id=?", [id])
  end

  test "writers wait for the lock in order" do
    %{"id" => id} = DB.one("SELECT id FROM accounts LIMIT 1")
    holder = hold_transaction(id, "first")
    parent = self()

    waiters =
      for {name, queued} <- [{"second", 1}, {"third", 2}] do
        task =
          Task.async(fn ->
            DB.transaction(fn query ->
              send(parent, {:writing, name})
              query.("UPDATE accounts SET name=? WHERE id=?", [name, id])
            end)
          end)

        # Queue them in a known order.
        wait_until(fn -> :queue.len(:sys.get_state(DB).waiting) == queued end)
        task
      end

    refute_received {:writing, _}
    send(holder.pid, :release_writer)
    assert :ok = Task.await(holder)
    Enum.each(waiters, &Task.await/1)
    assert_received {:writing, "second"}
    assert_received {:writing, "third"}
    assert %{"name" => "third"} = DB.one("SELECT name FROM accounts WHERE id=?", [id])
  end

  test "an owner that exits mid-transaction is rolled back and the lock passes on" do
    %{"id" => id, "name" => original} = DB.one("SELECT id, name FROM accounts LIMIT 1")
    holder = hold_transaction(id, "never committed")

    waiter =
      Task.async(fn -> DB.query("UPDATE accounts SET updated_at=? WHERE id=?", ["after", id]) end)

    wait_until(fn -> :queue.len(:sys.get_state(DB).waiting) == 1 end)

    Process.unlink(holder.pid)
    Process.exit(holder.pid, :kill)

    assert [] = Task.await(waiter)
    assert %{"name" => ^original} = DB.one("SELECT name FROM accounts WHERE id=?", [id])
    assert %{owner: nil} = :sys.get_state(DB)
  end

  test "waiters that exit before their turn are skipped" do
    %{"id" => id} = DB.one("SELECT id FROM accounts LIMIT 1")
    holder = hold_transaction(id, "held")
    gone = spawn(fn -> DB.query("UPDATE accounts SET updated_at='gone' WHERE id=?", [id]) end)
    wait_until(fn -> :queue.len(:sys.get_state(DB).waiting) == 1 end)
    Process.exit(gone, :kill)
    wait_until(fn -> :queue.len(:sys.get_state(DB).waiting) == 0 end)

    send(holder.pid, :release_writer)
    assert :ok = Task.await(holder)
    assert [] = DB.query("UPDATE accounts SET name='next' WHERE id=?", [id])
    assert %{owner: nil} = :sys.get_state(DB)
  end

  test "all readers reject writes and retain their connection settings" do
    assert length(readers()) == min(System.schedulers_online(), 8)
    original = DB.one("SELECT id, name FROM accounts LIMIT 1")

    for reader <- readers() do
      assert {:error, _} =
               SQLite.query(reader, "UPDATE accounts SET name=?", ["must not persist"])

      for {pragma, value} <- [
            {"foreign_keys", 1},
            {"journal_mode", "wal"},
            {"synchronous", 1},
            {"cache_size", -2000},
            {"mmap_size", 0}
          ] do
        assert {:ok, [%{^pragma => ^value}]} = SQLite.query(reader, "PRAGMA #{pragma}")
      end

      assert {:ok, [^original]} = SQLite.query(reader, "SELECT id, name FROM accounts LIMIT 1")
    end
  end

  test "all readers observe commits and recreated fixture schemas without stale statements" do
    %{"id" => id} = DB.one("SELECT id FROM accounts LIMIT 1")
    assert [] = DB.query("UPDATE accounts SET name=? WHERE id=?", ["new committed name", id])

    for reader <- readers() do
      assert {:ok, [%{"name" => "new committed name"}]} =
               SQLite.query(reader, "SELECT name FROM accounts WHERE id=?", [id])
    end

    assert :ok = DB.restore_fixture(@fixture)
    original = Enum.find(@fixture["tables"]["accounts"], &(&1["id"] == id))["name"]

    for reader <- readers() do
      assert {:ok, [%{"name" => ^original}]} =
               SQLite.query(reader, "SELECT name FROM accounts WHERE id=?", [id])
    end
  end

  defp wait_until(fun, attempts \\ 200) do
    cond do
      fun.() ->
        :ok

      attempts == 0 ->
        flunk("condition not met")

      true ->
        Process.sleep(5)
        wait_until(fun, attempts - 1)
    end
  end

  test "expected SQLite errors are returned without crashing the writer" do
    assert {:error, %DB.Error{}} = DB.query("SELECT * FROM missing_table")
    assert {:error, %DB.Error{}} = DB.one("SELECT * FROM missing_table")
    assert %{"count" => _} = DB.one("SELECT COUNT(*) AS count FROM messages")
  end

  test "invalid bindings raise in the caller without restarting connection owners" do
    writer = Process.whereis(DB)

    for _ <- 1..4, sql <- ["SELECT ? AS value", "UPDATE accounts SET name=?"] do
      assert_raise ArgumentError, "unsupported type: %{}", fn -> DB.query(sql, [%{}]) end
      assert Process.whereis(DB) == writer
      assert %{"value" => 19} = DB.one("SELECT ? AS value", [19])
    end

    assert %{owner: nil} = :sys.get_state(DB)
  end

  test "transactions read their own writes through the public query API" do
    %{"id" => account_id} = DB.one("SELECT id FROM accounts LIMIT 1")

    assert :ok =
             DB.transaction(fn query ->
               query.("UPDATE accounts SET name=? WHERE id=?", [
                 "Updated in transaction",
                 account_id
               ])

               assert DB.one("SELECT name FROM accounts WHERE id=?", [account_id])["name"] ==
                        "Updated in transaction"

               :ok
             end)
  end

  test "transaction exceptions, throws and exits roll back without killing the writer" do
    writer = Process.whereis(DB)
    %{"id" => id, "name" => original} = DB.one("SELECT id, name FROM accounts LIMIT 1")
    error = %RuntimeError{message: "unexpected callback failure"}

    for kind <- [:error, :throw, :exit] do
      fail = fn ->
        DB.transaction(fn query ->
          query.("UPDATE accounts SET name=? WHERE id=?", ["must roll back", id])
          :erlang.raise(kind, error, [])
        end)
      end

      case kind do
        :error -> assert catch_error(fail.()) == error
        :throw -> assert catch_throw(fail.()) == error
        :exit -> assert catch_exit(fail.()) == error
      end

      assert Process.whereis(DB) == writer
      assert %{"name" => ^original} = DB.one("SELECT name FROM accounts WHERE id=?", [id])
      assert [] = DB.query("UPDATE accounts SET name=? WHERE id=?", [original, id])
    end
  end
end
