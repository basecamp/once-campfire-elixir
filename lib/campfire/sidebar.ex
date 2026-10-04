defmodule Campfire.Sidebar do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Broadcasts, DB, MessagesView, Rails}
  require EEx
  EEx.function_from_file(:defp, :frame, "priv/templates/sidebar.html.eex", [:assigns])
  EEx.function_from_file(:defp, :direct, "priv/templates/sidebar_direct.html.eex", [:assigns])
  EEx.function_from_file(:defp, :shared, "priv/templates/sidebar_shared.html.eex", [:assigns])

  EEx.function_from_file(:defp, :placeholder, "priv/templates/sidebar_placeholder.html.eex", [
    :assigns
  ])

  def show(conn) do
    {conn, user, session} = Auth.session_user(conn)

    if user do
      {conn, data} = Auth.csrf_session(conn)

      rows =
        DB.query(
          "SELECT r.*,m.unread_at FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? AND m.involvement!='invisible' ORDER BY LOWER(r.name)",
          [user["id"]]
        )

      {directs, others} = Enum.split_with(rows, &(&1["type"] == "Rooms::Direct"))

      excludes =
        DB.query(
          "SELECT DISTINCT user_id FROM memberships WHERE room_id IN (SELECT r.id FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? AND r.type='Rooms::Direct')",
          [user["id"]]
        )
        |> Enum.map(& &1["user_id"])
        |> then(&Enum.uniq([user["id"] | &1]))

      users =
        DB.query("SELECT * FROM users WHERE status=0 ORDER BY created_at")
        |> Enum.reject(&(&1["id"] in excludes))
        |> Enum.take(max(20 - length(excludes), 0))

      token = Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], "/rooms/directs", "POST"))
      account = DB.one("SELECT settings FROM accounts LIMIT 1")
      settings = Jason.decode!(account["settings"] || "{}")

      content =
        frame(
          user_id: user["id"],
          avatar: avatar_path(user),
          global_stream: Rails.sign_stream("rooms"),
          user_stream:
            Rails.sign_stream(
              Base.url_encode64("gid://campfire/User/#{user["id"]}", padding: false) <> ":rooms"
            ),
          create_allowed:
            user["role"] == 1 || !settings["restrict_room_creation_to_administrators"],
          directs:
            directs
            |> Enum.sort_by(& &1["updated_at"], :desc)
            |> Enum.map_join(&render_direct(&1, user)),
          shared:
            Enum.map_join(others, fn room ->
              "          " <>
                shared(
                  id: room["id"],
                  key: Broadcasts.room_key(room),
                  name: Assets.html_escape(room["name"]),
                  unread: !is_nil(room["unread_at"])
                )
            end),
          placeholders:
            Enum.map_join(users, fn u ->
              placeholder(
                id: u["id"],
                avatar: avatar_path(u),
                name: Assets.html_escape(first_name(u)),
                token: token
              )
            end)
        )

      {conn, html} = Campfire.Page.render(conn, user, data, content: content)

      conn
      |> Auth.set_auth_cookie(session)
      |> put_resp_content_type("text/html")
      |> send_resp(200, html)
    else
      Auth.request_authentication(conn)
    end
  end

  def avatar_path(user),
    do:
      "/users/#{Rails.signed_id("User", user["id"], "avatar")}/avatar?v=" <>
        (user["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14))

  defp first_name(user), do: user["name"] |> String.split() |> List.first() || ""

  def render_shared(room, unread \\ false) do
    shared(
      id: room["id"],
      key: Broadcasts.room_key(room),
      name: Assets.html_escape(room["name"] || ""),
      unread: unread
    )
  end

  def render_direct(room, user) do
    members =
      DB.query(
        "SELECT u.* FROM users u JOIN memberships m ON m.user_id=u.id WHERE m.room_id=? AND u.id!=?",
        [room["id"], user["id"]]
      )

    members = if members == [], do: [user], else: members

    {avatars, name} =
      if length(members) > 1 do
        images =
          members
          |> Enum.take(4)
          |> Enum.map_join(fn u ->
            ~s(          <span class="avatar">\n            <img aria-hidden="true" src="#{avatar_path(u)}" width="20" height="20" />\n          </span>\n)
          end)

        names =
          Enum.map(members, fn u ->
            u["name"]
            |> String.split()
            |> Enum.take(3)
            |> Enum.map_join(&(String.first(&1) |> String.upcase()))
          end)

        name =
          case names do
            [a, b] -> a <> "+" <> b
            names -> Enum.join(Enum.drop(names, -1), ", ") <> ", and " <> List.last(names)
          end

        {"      <div class=\"avatar__group\">\n" <> images <> "      </div>\n", name}
      else
        [u] = members

        {~s(      <span class="avatar">\n        <img aria-hidden="true" src="#{avatar_path(u)}" width="48" height="48" />\n      </span>\n),
         first_name(u)}
      end

    direct(
      id: room["id"],
      updated: MessagesView.epoch(room["updated_at"]),
      unread: !is_nil(room["unread_at"]),
      name: Assets.html_escape(name),
      avatars: String.trim_trailing(avatars, "\n")
    )
  end
end
