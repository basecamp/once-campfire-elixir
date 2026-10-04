defmodule Campfire.RoomsTest do
  use ExUnit.Case, async: false
  alias Campfire.{Chat, DB, People, Rooms}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  setup do
    DB.restore_fixture(@fixture)
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T16:00:00Z")
    on_exit(fn -> System.delete_env("CAMPFIRE_CLOCK") end)

    %{
      user: DB.one("SELECT * FROM users WHERE id=127326141"),
      other: DB.one("SELECT * FROM users WHERE id=149087659")
    }
  end

  test "direct rooms are singletons for the exact participant set", %{user: user, other: other} do
    room = Rooms.create(user, "Rooms::Direct", %{}, [other["id"]])
    same = Rooms.create(other, "Rooms::Direct", %{}, [user["id"], user["id"]])
    assert same["id"] == room["id"]
    own = Rooms.create(user, "Rooms::Direct", %{}, [])
    assert own["id"] != room["id"]

    assert DB.one("SELECT involvement FROM memberships WHERE room_id=? LIMIT 1", [room["id"]])[
             "involvement"
           ] == "everything"

    assert Rooms.update(room, "Rooms::Open", %{}) == {:error, :direct_room_type}
    refute Rooms.scoped(user, room["id"], "Rooms::Closed")
  end

  test "open membership includes active users and new users; conversion revises membership", %{
    user: user,
    other: other
  } do
    room = Rooms.create(user, "Rooms::Open", %{"name" => "Everyone"})
    active = DB.one("SELECT count(*) AS count FROM users WHERE status=0")["count"]

    assert DB.one("SELECT count(*) AS count FROM memberships WHERE room_id=?", [room["id"]])[
             "count"
           ] == active

    newcomer = People.create(%{"name" => "New member", "email_address" => "new@example.com"})
    assert Chat.room(newcomer, room["id"])
    closed = Rooms.update(room, "Rooms::Closed", %{"name" => "Private"}, [other["id"]])
    assert closed["name"] == "Private"
    refute Chat.room(user, room["id"])
    assert Chat.room(other, room["id"])
    opened = Rooms.update(closed, "Rooms::Open", %{})
    assert opened["type"] == "Rooms::Open"
    assert Chat.room(newcomer, room["id"])
  end

  test "deactivation preserves direct history but removes sessions and shared memberships", %{
    user: user,
    other: other
  } do
    room = Rooms.create(user, "Rooms::Direct", %{}, [other["id"]])
    updated = People.deactivate(user)
    assert updated["status"] == 1
    assert updated["email_address"] =~ "-deactivated-"
    assert Chat.room(user, room["id"])
    assert DB.query("SELECT * FROM sessions WHERE user_id=?", [user["id"]]) == []

    assert DB.query(
             "SELECT memberships.* FROM memberships JOIN rooms ON rooms.id=memberships.room_id WHERE user_id=? AND rooms.type!='Rooms::Direct'",
             [user["id"]]
           ) == []
  end

  test "room deletion removes rich text, search index, boosts and memberships", %{user: user} do
    room = Rooms.create(user, "Rooms::Closed", %{"name" => "Disposable"}, [user["id"]])
    message = Chat.create_message(user, room, "<p>deleteroomneedle</p>")
    Chat.create_boost(user, message, "+1")
    assert Rooms.destroy(room) == :ok
    assert DB.query("SELECT * FROM memberships WHERE room_id=?", [room["id"]]) == []
    assert DB.query("SELECT * FROM messages WHERE room_id=?", [room["id"]]) == []
    assert DB.query("SELECT * FROM boosts WHERE message_id=?", [message["id"]]) == []

    assert DB.query(
             "SELECT body FROM message_search_index WHERE message_search_index MATCH 'deleteroomneedle'"
           ) == []
  end
end
