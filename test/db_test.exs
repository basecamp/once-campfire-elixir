defmodule Campfire.DBTest do
  use ExUnit.Case, async: false
  alias Campfire.DB
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    :ok = DB.restore_fixture(@fixture)
  end

  test "reads use the pool while the writer is busy" do
    if Process.whereis(DB.ReadPool) do
      parent = self()
      %{"id" => id, "name" => original} = DB.one("SELECT id, name FROM accounts LIMIT 1")

      writer =
        Task.async(fn ->
          DB.transaction(fn query ->
            query.("UPDATE accounts SET name=? WHERE id=?", ["committed later", id])
            send(parent, :writer_started)

            receive do
              :release_writer -> :ok
            after
              5_000 -> raise "writer was not released"
            end
          end)
        end)

      on_exit(fn ->
        if Process.alive?(writer.pid) do
          if pid = Process.whereis(DB), do: send(pid, :release_writer)
        end
      end)

      assert_receive :writer_started

      reader = Task.async(fn -> DB.one("SELECT name FROM accounts WHERE id=?", [id]) end)
      assert {:ok, %{"name" => ^original}} = Task.yield(reader, 1_000)

      send(Process.whereis(DB), :release_writer)
      assert :ok = Task.await(writer)
      assert %{"name" => "committed later"} = DB.one("SELECT name FROM accounts WHERE id=?", [id])
    else
      assert System.schedulers_online() == 1
    end
  end

  @tag skip: System.schedulers_online() == 1
  test "all readers reject writes and retain read-pool connection settings" do
    readers = PartitionSupervisor.which_children(DB.ReadPool)
    assert length(readers) == min(System.schedulers_online(), 8)
    assert readers |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == length(readers)
    original = DB.one("SELECT id, name FROM accounts LIMIT 1")

    for {_, pid, :worker, _} <- readers do
      assert {:error, %DB.Error{}} =
               GenServer.call(pid, {:query, "UPDATE accounts SET name=?", ["must not persist"]})

      for {pragma, value} <- [
            {"foreign_keys", 1},
            {"journal_mode", "wal"},
            {"synchronous", 1},
            {"cache_size", -2000},
            {"mmap_size", 0}
          ] do
        assert [%{^pragma => ^value}] = GenServer.call(pid, {:query, "PRAGMA #{pragma}", []})
      end

      assert [^original] =
               GenServer.call(pid, {:query, "SELECT id, name FROM accounts LIMIT 1", []})
    end
  end

  @tag skip: System.schedulers_online() == 1
  test "all readers observe commits and recreated fixture schemas without stale statements" do
    %{"id" => id} = DB.one("SELECT id FROM accounts LIMIT 1")
    assert [] = DB.query("UPDATE accounts SET name=? WHERE id=?", ["new committed name", id])
    readers = PartitionSupervisor.which_children(DB.ReadPool)

    for {_, pid, :worker, _} <- readers do
      assert [%{"name" => "new committed name"}] =
               GenServer.call(pid, {:query, "SELECT name FROM accounts WHERE id=?", [id]})
    end

    assert :ok = DB.restore_fixture(@fixture)
    original = Enum.find(@fixture["tables"]["accounts"], &(&1["id"] == id))["name"]

    for {_, pid, :worker, _} <- readers do
      assert [%{"name" => ^original}] =
               GenServer.call(pid, {:query, "SELECT name FROM accounts WHERE id=?", [id]})
    end
  end

  @tag skip: System.schedulers_online() == 1
  test "restarting a reader restores its route without restarting the writer or other readers" do
    writer = Process.whereis(DB)
    readers = PartitionSupervisor.which_children(DB.ReadPool)
    route = {:via, PartitionSupervisor, {DB.ReadPool, self()}}
    reader = GenServer.whereis(route)
    {partition, ^reader, :worker, _} = Enum.find(readers, &(elem(&1, 1) == reader))
    original = DB.one("SELECT id, name FROM accounts LIMIT 1")

    assert :ok = Supervisor.terminate_child(DB.ReadPool, partition)
    assert {:ok, replacement} = Supervisor.restart_child(DB.ReadPool, partition)
    assert replacement != reader
    assert GenServer.whereis(route) == replacement
    assert Process.whereis(DB) == writer

    assert List.keydelete(PartitionSupervisor.which_children(DB.ReadPool), partition, 0) ==
             List.keydelete(readers, partition, 0)

    assert ^original = DB.one("SELECT id, name FROM accounts LIMIT 1")

    assert {:error, %DB.Error{}} =
             GenServer.call(replacement, {:query, "UPDATE accounts SET name=?", ["read only"]})
  end

  test "expected SQLite errors are returned without crashing the writer" do
    assert {:error, %DB.Error{}} = DB.query("SELECT * FROM missing_table")
    assert {:error, %DB.Error{}} = DB.one("SELECT * FROM missing_table")
    assert %{"count" => _} = DB.one("SELECT COUNT(*) AS count FROM messages")
  end

  test "invalid bindings raise in the caller without restarting connection owners" do
    writer = Process.whereis(DB)

    reader =
      if Process.whereis(DB.ReadPool),
        do: GenServer.whereis({:via, PartitionSupervisor, {DB.ReadPool, self()}}),
        else: writer

    for _ <- 1..4, sql <- ["SELECT ? AS value", "UPDATE accounts SET name=?"] do
      assert_raise ArgumentError, "unsupported type: %{}", fn -> DB.query(sql, [%{}]) end
      assert Process.alive?(reader)
      assert Process.whereis(DB) == writer
      assert %{"value" => 19} = DB.one("SELECT ? AS value", [19])
    end
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
