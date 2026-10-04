defmodule Campfire.Navigation do
  import Plug.Conn
  alias Campfire.{Auth, Chat, DB, Page}
  require EEx
  EEx.function_from_file(:defp, :empty_rooms, "priv/templates/welcome.html.eex", [:assigns])
  EEx.function_from_file(:defp, :sidebar, "priv/templates/room_sidebar.html.eex", [:_assigns])

  def welcome(conn) do
    {conn, user, session} = Auth.session_user(conn)

    if user do
      conn = Auth.set_auth_cookie(conn, session)
      last = if conn.cookies["last_room"], do: Chat.room(user, conn.cookies["last_room"])

      room =
        last ||
          DB.one(
            "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.created_at LIMIT 1",
            [user["id"]]
          )

      if room do
        Auth.redirect(conn, "/rooms/#{room["id"]}")
      else
        {conn, data} = Auth.csrf_session(conn)

        {conn, html} =
          Page.render(conn, user, data,
            title: "No rooms yet",
            body_class: "sidebar",
            content: empty_rooms(name: user["name"]),
            sidebar: sidebar([])
          )

        conn |> put_resp_content_type("text/html") |> send_resp(200, html)
      end
    else
      Auth.request_authentication(conn)
    end
  end

  # The pinned Rails Directs controller replaces set_room's callback scope with
  # edit/destroy; inherited show reaches remember_last_room_visited with nil.
  def direct_room(conn, _id) do
    {conn, user, _session} = Auth.session_user(conn)
    if user, do: Campfire.HttpResponse.error(conn, 500), else: Auth.request_authentication(conn)
  end

  def shared_room(conn, id) do
    {conn, user, session} = Auth.session_user(conn)

    if user do
      conn = Auth.set_auth_cookie(conn, session)

      case Chat.room(user, id) do
        %{"type" => type} = room when type != "Rooms::Direct" ->
          conn
          |> put_resp_cookie("last_room", to_string(room["id"]),
            max_age: DateTime.diff(Auth.permanent_expiry(), Campfire.Clock.now())
          )
          |> Auth.redirect("/rooms/#{room["id"]}")

        _ ->
          conn
          |> Campfire.Flash.put("alert", "Room not found or inaccessible")
          |> Auth.redirect("/")
      end
    else
      Auth.request_authentication(conn)
    end
  end

  def rooms_index(conn) do
    {conn, user, session} = Auth.session_user(conn)

    if user do
      room =
        DB.one(
          "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.id DESC LIMIT 1",
          [user["id"]]
        )

      if room,
        do: conn |> Auth.set_auth_cookie(session) |> Auth.redirect("/rooms/#{room["id"]}"),
        else: send_resp(conn, 500, "")
    else
      Auth.request_authentication(conn)
    end
  end
end
