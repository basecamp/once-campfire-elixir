defmodule Campfire.ChatTest do
  use ExUnit.Case, async: false
  alias Campfire.{Chat, DB}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  setup do
    :ok = DB.restore_fixture(@fixture)
    Campfire.Clock.set("2026-03-02T16:00:00Z")
    on_exit(fn -> Campfire.Clock.set(nil) end)
    user = Chat.bot("394959859-BenderBot123")
    room = Chat.room(user, 486_777_696)
    %{user: user, room: room}
  end

  test "membership scopes bots and deactivated bots cannot authenticate", %{user: user} do
    assert Chat.room(user, 486_777_696)
    refute Chat.room(user, 211_839_384)
    refute Chat.bot("773523957-OldBot789abc")
    refute Chat.bot("394959859-wrong")
  end

  test "message writes update FTS and touch the room", %{user: user, room: room} do
    m = Chat.create_message(user, room, "<p>parityneedle bravo</p>")
    assert m["creator_id"] == user["id"]

    assert DB.one(
             "SELECT body FROM message_search_index WHERE message_search_index MATCH 'parityneedle'"
           )["body"] == "parityneedle bravo"

    assert DB.one("SELECT updated_at FROM rooms WHERE id=?", [room["id"]])["updated_at"] ==
             "2026-03-02 16:00:00"

    updated = Chat.update_message(m, "<p>replacementneedle</p>")
    assert updated["id"] == m["id"]

    refute DB.one(
             "SELECT body FROM message_search_index WHERE message_search_index MATCH 'parityneedle'"
           )

    assert DB.one(
             "SELECT body FROM message_search_index WHERE message_search_index MATCH 'replacementneedle'"
           )
  end

  test "presence TTL controls unread updates", %{user: user, room: room} do
    DB.query(
      "UPDATE memberships SET unread_at=NULL,connected_at='2026-03-02 15:59:01',connections=1 WHERE room_id=? AND user_id=127326141",
      [room["id"]]
    )

    DB.query(
      "UPDATE memberships SET unread_at=NULL,connected_at='2026-03-02 15:58:59',connections=1 WHERE room_id=? AND user_id=149087659",
      [room["id"]]
    )

    Chat.create_message(user, room, "<p>TTL check</p>")

    refute DB.one("SELECT unread_at FROM memberships WHERE room_id=? AND user_id=127326141", [
             room["id"]
           ])["unread_at"]

    assert DB.one("SELECT unread_at FROM memberships WHERE room_id=? AND user_id=149087659", [
             room["id"]
           ])["unread_at"] == "2026-03-02 16:00:00"
  end

  test "failed writes roll back and leave the DB process alive", %{user: user, room: room} do
    before = DB.one("SELECT COUNT(*) AS count FROM messages")["count"]
    assert {:error, _} = Chat.create_message(Map.put(user, "id", -1), room, "bad creator")
    assert DB.one("SELECT COUNT(*) AS count FROM messages")["count"] == before
    assert {:error, _} = DB.query("SELECT * FROM missing_table")
    assert DB.one("SELECT COUNT(*) AS count FROM messages")["count"] == before
  end

  test "deletion removes boosts, rich text, and search rows", %{user: user, room: room} do
    m = Chat.create_message(user, room, "delete me")
    now = Chat.timestamp()

    DB.query(
      "INSERT INTO boosts (booster_id,message_id,content,created_at,updated_at) VALUES (?,?,?,?,?)",
      [user["id"], m["id"], "+1", now, now]
    )

    assert :ok = Chat.delete_message(m)
    refute DB.one("SELECT id FROM messages WHERE id=?", [m["id"]])
    refute DB.one("SELECT id FROM boosts WHERE message_id=?", [m["id"]])

    refute DB.one(
             "SELECT id FROM action_text_rich_texts WHERE record_type='Message' AND record_id=?",
             [m["id"]]
           )

    refute DB.one("SELECT rowid FROM message_search_index WHERE rowid=?", [m["id"]])
  end

  test "pagination uses timestamps, bounds page size, and scopes the cursor", %{room: room} do
    latest = Chat.messages(room, %{})
    assert length(latest) == 40
    earlier = Chat.messages(room, %{"before" => to_string(hd(latest)["id"])})
    assert length(earlier) == 40
    assert List.last(earlier)["created_at"] < hd(latest)["created_at"]
    assert {:error, :not_found} = Chat.messages(room, %{"after" => "0"})
  end
end
