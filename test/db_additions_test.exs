defmodule Campfire.DBAdditionsTest do
  use ExUnit.Case, async: true
  alias Exqlite.Sqlite3, as: SQL
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  @tag :tmp_dir
  test "boot adds the messages paging index to an existing Rails database", %{tmp_dir: dir} do
    path = Path.join(dir, "existing.sqlite3")
    {:ok, db} = SQL.open(path)
    for sql <- @fixture["schema"], do: :ok = SQL.execute(db, sql)
    :ok = SQL.close(db)

    {:ok, {db, _} = conn, _} = Campfire.DB.Connection.init_worker({:writer, path})

    try do
      assert [%{"name" => "index_messages_on_room_id_and_created_at"}] =
               Campfire.DB.run(
                 conn,
                 "SELECT name FROM sqlite_master WHERE type='index' AND name='index_messages_on_room_id_and_created_at'",
                 []
               )

      plan =
        Campfire.DB.run(
          conn,
          "EXPLAIN QUERY PLAN SELECT * FROM messages WHERE room_id=? ORDER BY created_at DESC LIMIT 40",
          [1]
        )
        |> Enum.map_join("\n", & &1["detail"])

      assert plan =~ "index_messages_on_room_id_and_created_at"
      refute plan =~ "TEMP B-TREE"
    after
      SQL.close(db)
    end
  end
end
