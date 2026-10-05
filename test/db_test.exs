defmodule Campfire.DBTest do
  use ExUnit.Case, async: false
  alias Campfire.DB
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  setup do
    :ok = DB.restore_fixture(@fixture)
    DB.query("CREATE TABLE db_test (n INTEGER NOT NULL)")
    :ok
  end

  test "pooled connections serialize concurrent write transactions" do
    1..50
    |> Task.async_stream(
      fn n -> DB.transaction(fn q -> q.("INSERT INTO db_test (n) VALUES (?)", [n]) end) end,
      max_concurrency: 16
    )
    |> Enum.each(&assert(&1 == {:ok, []}))

    assert DB.one("SELECT count(*) AS c, sum(n) AS s FROM db_test") == %{"c" => 50, "s" => 1275}
  end

  test "a failing transaction rolls back and returns an error" do
    assert {:error, %Exqlite.Error{}} =
             DB.transaction(fn q ->
               q.("INSERT INTO db_test (n) VALUES (1)", [])
               q.("INSERT INTO db_test (n) VALUES (NULL)", [])
             end)

    assert {:error, %RuntimeError{}} =
             DB.transaction(fn q ->
               q.("INSERT INTO db_test (n) VALUES (2)", [])
               raise "boom"
             end)

    assert DB.query("SELECT n FROM db_test") == []
    assert {:error, %Exqlite.Error{}} = DB.query("SELECT nope FROM db_test")
  end
end
