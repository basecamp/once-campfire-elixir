defmodule Campfire.Refresh do
  import Plug.Conn
  alias Campfire.{Auth, Broadcasts, Chat, DB, MessagesView}

  def show(conn, room_id) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      true ->
        if room = Chat.room(user, room_id) do
          since =
            DateTime.from_unix!(Chat.integer(conn.params["since"]), :millisecond)
            |> Chat.timestamp()

          new =
            DB.query(
              "SELECT * FROM messages WHERE room_id=? AND created_at>? ORDER BY created_at LIMIT 40",
              [room["id"], since]
            )

          excluded = Enum.map(new, & &1["id"])

          updated =
            DB.query(
              "SELECT * FROM messages WHERE room_id=? AND updated_at>? AND id NOT IN (SELECT value FROM json_each(?)) ORDER BY +created_at DESC LIMIT 40",
              [room["id"], since, Jason.encode!(excluded)]
            )
            |> Enum.reverse()

          {conn, data} = Auth.browser_session(conn)

          append =
            if new == [],
              do: "",
              else:
                ~s(<turbo-stream action="append" target="messages_#{Broadcasts.room_key(room)}"><template>\n  \n#{Enum.map_join(new, &MessagesView.render(&1, Auth.base(conn)))}</template></turbo-stream>)

          replaces =
            Enum.map_join(updated, fn message ->
              ~s(  <turbo-stream action="replace" target="message_#{message["client_message_id"]}"><template>\n#{MessagesView.render(message, Auth.base(conn)) |> String.trim_trailing("\n")}</template></turbo-stream>\n)
            end)

          conn
          |> Auth.set_auth_cookie(session)
          |> Auth.set_browser_session(data)
          |> put_resp_content_type("text/vnd.turbo-stream.html")
          |> send_resp(200, append <> "\n" <> replaces)
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(404, ~s({"status":404,"error":"Not Found"}))
        end
    end
  end
end
