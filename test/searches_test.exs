defmodule Campfire.SearchesTest do
  use ExUnit.Case, async: false
  alias Campfire.{DB, Searches}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    DB.restore_fixture(@fixture)
    :ok
  end

  test "bounded search retains sparse reachable matches and quotes literal operators" do
    user_id = 127_326_141

    room_id =
      DB.one("SELECT room_id FROM memberships WHERE user_id=? LIMIT 1", [user_id])["room_id"]

    private = DB.one("SELECT id FROM rooms WHERE id!=? LIMIT 1", [room_id])["id"]
    DB.query("DELETE FROM memberships WHERE user_id=? AND room_id=?", [user_id, private])

    DB.transaction(fn query ->
      for i <- 0..1100 do
        room = if i == 0, do: room_id, else: private

        query.(
          "INSERT INTO messages(room_id,creator_id,client_message_id,created_at,updated_at) VALUES (?,?,?,'2026-10-07 00:00:00','2026-10-07 00:00:00')",
          [room, user_id, "sparse-#{i}"]
        )

        query.("INSERT INTO message_search_index(rowid,body) VALUES (last_insert_rowid(),?)", [
          "searchsparseonly"
        ])
      end
    end)

    visible = DB.one("SELECT id FROM messages WHERE client_message_id='sparse-0'")["id"]
    assert Enum.map(Searches.messages(user_id, "searchsparseonly"), & &1["id"]) == [visible]
    DB.query("DELETE FROM memberships WHERE user_id=? AND room_id=?", [user_id, room_id])
    assert Searches.messages(user_id, "searchsparseonly") == []
    assert Searches.messages(user_id, "searchsparseonly AND") == []

    DB.query(
      "INSERT INTO memberships(user_id,room_id,created_at,updated_at) VALUES (?,?,'2026-10-07 00:00:00','2026-10-07 00:00:00')",
      [user_id, private]
    )

    assert length(Searches.messages(user_id, "searchsparseonly")) == 100
  end
end
