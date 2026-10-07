defmodule Campfire.RoomPage do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  import Plug.Conn
  alias Campfire.{Assets, Auth, Broadcasts, Chat, DB, MessagesView, Rails}
  require EEx
  EEx.function_from_file(:defp, :nav, "priv/templates/room_nav.html.eex", [:assigns])
  EEx.function_from_file(:defp, :head, "priv/templates/room_head.html.eex", [:assigns])
  EEx.function_from_file(:defp, :content, "priv/templates/room_content.html.eex", [:assigns])
  EEx.function_from_file(:defp, :footer, "priv/templates/room_footer.html.eex", [:assigns])
  EEx.function_from_file(:defp, :sidebar, "priv/templates/room_sidebar.html.eex", [:_assigns])

  EEx.function_from_file(:defp, :invitation, "priv/templates/invitation.html.eex", [:assigns])

  def show(conn, room_id, message_id \\ nil) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      true ->
        if room = Chat.room(user, room_id) do
          {conn, data} = Auth.csrf_session(conn)
          token = Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"]))
          messages = messages(room, message_id)
          account = DB.one("SELECT * FROM accounts LIMIT 1")
          gid = Base.url_encode64("gid://campfire/#{room["type"]}/#{room["id"]}", padding: false)
          name = display_name(room, user)

          assigns = [
            pwa: Campfire.Pwa.render(conn, :room),
            user_id: user["id"],
            user_avatar: Campfire.Mentions.avatar(user, :page),
            user_name: Assets.html_escape(user["name"]),
            admin: user["role"] == 1,
            direct: room["type"] == "Rooms::Direct",
            room_id: room["id"],
            room_key: Broadcasts.room_key(room),
            room_name: Assets.html_escape(name),
            namespace: namespace(room),
            room_updated: MessagesView.epoch(room["updated_at"]),
            base: Assets.html_escape(Auth.base(conn)),
            meta_token: token,
            form_token:
              Rails.csrf_mask(
                Rails.csrf_form(data["_csrf_token"], "/rooms/#{room["id"]}/messages", "POST")
              ),
            vapid: Assets.html_escape(System.get_env("VAPID_PUBLIC_KEY", "")),
            account_version:
              account["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14),
            stream: Rails.sign_stream(gid <> ":messages"),
            invitation: invitation_for(conn, user, data, account, room),
            messages: MessagesView.render_many(messages, Auth.base(conn), token)
          ]

          {conn, html} =
            Campfire.Page.render(conn, user, data,
              title: Assets.html_escape(name),
              body_class: "sidebar",
              head: head(assigns),
              nav: nav(assigns),
              content: content(assigns),
              footer: footer(assigns),
              sidebar: sidebar(assigns)
            )

          conn
          |> Auth.set_auth_cookie(session)
          |> put_resp_cookie("last_room", to_string(room["id"]),
            max_age: DateTime.diff(Auth.permanent_expiry(), Campfire.Clock.now())
          )
          |> put_resp_content_type("text/html")
          |> send_resp(200, html)
        else
          conn
          |> Campfire.Flash.put("alert", "Room not found or inaccessible")
          |> Auth.redirect("/")
        end
    end
  rescue
    Campfire.Pwa.MissingAsset ->
      Campfire.HttpResponse.exception(conn, 500, Campfire.Assets.read("public/500.html"))
  end

  defp invitation_for(conn, user, data, account, room) do
    original = DB.one("SELECT id FROM rooms ORDER BY created_at LIMIT 1")

    count =
      DB.one("SELECT count(*) AS count FROM messages WHERE room_id=?", [room["id"]])["count"]

    if original["id"] == room["id"] && count <= 40 do
      url = Auth.base(conn) <> "/join/" <> account["join_code"]

      invitation(
        admin: user["role"] == 1,
        account_version:
          account["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14),
        join_url: Assets.html_escape(url),
        qr: Base.url_encode64(url),
        join_token:
          Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], "/account/join_code", "POST"))
      )
    else
      "    \n"
    end
  end

  def display_name(%{"type" => "Rooms::Direct"} = room, user) do
    names =
      DB.query("SELECT u.* FROM users u JOIN memberships m ON m.user_id=u.id WHERE m.room_id=?", [
        room["id"]
      ])
      |> Enum.reject(&(user && &1["id"] == user["id"]))
      |> Enum.map(& &1["name"])

    case names do
      [] -> user["name"]
      [name] -> name
      [first, last] -> first <> " and " <> last
      names -> Enum.join(Enum.drop(names, -1), ", ") <> ", and " <> List.last(names)
    end
  end

  def display_name(room, _), do: room["name"] || ""

  defp namespace(room),
    do:
      %{"Rooms::Closed" => "closeds", "Rooms::Open" => "opens", "Rooms::Direct" => "directs"}[
        room["type"]
      ]

  defp messages(room, message_id) do
    if message_id &&
         DB.one("SELECT id FROM messages WHERE room_id=? AND id=?", [
           room["id"],
           Chat.integer(message_id)
         ]) do
      anchor =
        DB.one("SELECT * FROM messages WHERE room_id=? AND id=?", [
          room["id"],
          Chat.integer(message_id)
        ])

      Chat.messages(room, %{"before" => to_string(anchor["id"])}) ++
        [anchor] ++ Chat.messages(room, %{"after" => to_string(anchor["id"])})
    else
      Chat.messages(room, %{})
    end
  end
end
