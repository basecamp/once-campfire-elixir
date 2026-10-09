defmodule Campfire.Broadcasts do
  alias Campfire.{Cable, DB, MessagesView}

  def create(room, message, base \\ System.get_env("APP_URL", "http://example.org"), _user \\ nil) do
    html = "\n" <> String.trim_trailing(MessagesView.render(message, base), "\n")

    append =
      ~s(<turbo-stream action="append" target="messages_#{room_key(room)}"><template>#{html}</template></turbo-stream>)

    unreads =
      for membership <- DB.query("SELECT user_id FROM memberships WHERE room_id=?", [room["id"]]),
          do: {"user_#{membership["user_id"]}_unreads", %{"roomId" => room["id"]}}

    Cable.broadcast_all([{Cable.messages_stream(room), append} | unreads])
  end

  def remove(room, message),
    do:
      Cable.broadcast(
        Cable.messages_stream(room),
        ~s(<turbo-stream action="remove" target="message_#{message["client_message_id"]}"></turbo-stream>)
      )

  def replace(room, message) do
    html = MessagesView.presentation_element(message)

    Cable.broadcast(
      Cable.messages_stream(room),
      ~s(<turbo-stream maintain_scroll="true" action="replace" target="presentation_message_#{message["client_message_id"]}"><template>#{html}</template></turbo-stream>)
    )
  end

  def boost_create(message, boost) do
    room = DB.one("SELECT * FROM rooms WHERE id=?", [message["room_id"]])
    html = MessagesView.render_boost(boost)

    Cable.broadcast(
      Cable.messages_stream(room),
      ~s(<turbo-stream maintain_scroll="true" action="append" target="boosts_message_#{message["client_message_id"]}"><template>#{html}</template></turbo-stream>)
    )
  end

  def boost_remove(message, boost) do
    room = DB.one("SELECT * FROM rooms WHERE id=?", [message["room_id"]])

    Cable.broadcast(
      Cable.messages_stream(room),
      ~s(<turbo-stream action="remove" target="boost_#{boost["id"]}"></turbo-stream>)
    )
  end

  def room_create(room) do
    if room["type"] == "Rooms::Direct" do
      for membership <- DB.query("SELECT * FROM memberships WHERE room_id=?", [room["id"]]) do
        user = DB.one("SELECT * FROM users WHERE id=?", [membership["user_id"]])

        html =
          Campfire.Sidebar.render_direct(
            Map.put(room, "unread_at", membership["unread_at"]),
            user
          )

        Cable.broadcast(user_rooms(user["id"]), stream("prepend", "direct_rooms", "\n" <> html))
      end
    else
      room_shared(room, "prepend", "shared_rooms")
    end
  end

  def involvement(user, room, before, after_value) do
    cond do
      room["type"] == "Rooms::Direct" ->
        :ok

      after_value == "invisible" ->
        Cable.broadcast(
          user_rooms(user["id"]),
          ~s(<turbo-stream action="remove" target="list_#{room_key(room)}"></turbo-stream>)
        )

      before == "invisible" ->
        Cable.broadcast(
          user_rooms(user["id"]),
          stream("prepend", "shared_rooms", Campfire.Sidebar.render_shared(room))
        )

      true ->
        :ok
    end
  end

  def room_update(room), do: room_shared(room, "replace", "list_" <> room_key(room))

  def room_remove(room),
    do:
      Cable.broadcast(
        "rooms",
        ~s(<turbo-stream action="remove" target="list_#{room_key(room)}"></turbo-stream>)
      )

  defp room_shared(room, action, target) do
    html = Campfire.Sidebar.render_shared(room)
    payload = stream(action, target, html)

    if room["type"] == "Rooms::Open" do
      Cable.broadcast("rooms", payload)
    else
      for membership <- DB.query("SELECT user_id FROM memberships WHERE room_id=?", [room["id"]]),
          do: Cable.broadcast(user_rooms(membership["user_id"]), payload)
    end
  end

  defp user_rooms(id),
    do: Base.url_encode64("gid://campfire/User/#{id}", padding: false) <> ":rooms"

  defp stream(action, target, html),
    do:
      ~s(<turbo-stream action="#{action}" target="#{target}"><template>#{String.trim_trailing(html, "\n")}</template></turbo-stream>)

  def room_key(room),
    do:
      Macro.underscore(String.replace(room["type"], "::", "."))
      |> String.replace("/", "_")
      |> then(&(&1 <> "_#{room["id"]}"))
end
