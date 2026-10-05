defmodule Campfire.RoomForms do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Chat, DB, Flash, Mentions, Page, RoomPage}
  require EEx

  for branch <-
        ~w(open_new closed_new open_edit closed_edit open_readonly closed_readonly direct_new direct_edit) do
    EEx.function_from_file(
      :defp,
      String.to_atom(branch),
      "priv/templates/form_#{branch}.html.eex",
      # The new-direct-room form uses no assigns.
      [if(branch == "direct_new", do: :_assigns, else: :assigns)]
    )

    defp content(unquote(branch), assigns), do: unquote(String.to_atom(branch))(assigns)
  end

  for branch <- ~w(open closed readonly new_self direct) do
    EEx.function_from_file(
      :defp,
      String.to_atom("user_#{branch}"),
      "priv/templates/room_user_#{branch}.html.eex",
      [:assigns]
    )

    defp user_content(unquote(branch), assigns),
      do: unquote(String.to_atom("user_#{branch}"))(assigns)
  end

  EEx.function_from_file(:defp, :nav, "priv/templates/room_form_nav.html.eex", [:assigns])

  def show(conn, kind, id \\ nil) do
    {conn, user, session} = Auth.session_user(conn)
    conn = if user, do: Auth.set_auth_cookie(conn, session), else: conn
    room = if id, do: Chat.room(user, id), else: %{"name" => "New room", "id" => nil}
    account = DB.one("SELECT * FROM accounts LIMIT 1") || %{}
    settings = Jason.decode!(account["settings"] || "{}")

    cond do
      !user ->
        Auth.request_authentication(conn)

      is_nil(room) || (id && room["type"] == "Rooms::Direct" != (kind == "direct")) ->
        conn |> Flash.put("alert", "Room not found or inaccessible") |> Auth.redirect("/")

      !id && kind != "direct" && settings["restrict_room_creation_to_administrators"] &&
          user["role"] != 1 ->
        head(conn, 403)

      true ->
        {conn, data} = Auth.csrf_session(conn)
        edit = !is_nil(id)
        admin = !edit || user["role"] == 1 || user["id"] == room["creator_id"]

        branch =
          kind <>
            if(edit,
              do: if(admin || kind == "direct", do: "_edit", else: "_readonly"),
              else: "_new"
            )

        users =
          if kind == "direct" && edit,
            do:
              DB.query(
                "SELECT u.* FROM users u JOIN memberships m ON m.user_id=u.id WHERE m.room_id=?",
                [room["id"]]
              ),
            else: DB.query("SELECT * FROM users WHERE status=0 ORDER BY LOWER(name)")

        selected_ids =
          if edit,
            do:
              DB.query("SELECT user_id FROM memberships WHERE room_id=?", [room["id"]])
              |> Enum.map(& &1["user_id"]),
            else: []

        {selected, unselected} = Enum.split_with(users, &(&1["id"] in selected_ids))

        direct_users =
          if length(users) > 1, do: Enum.reject(users, &(&1["id"] == user["id"])), else: users

        render_user = fn target, selected ->
          render_user(target, user, kind, edit, admin, selected)
        end

        back_room =
          (conn.cookies["last_room"] && Chat.room(user, conn.cookies["last_room"])) ||
            DB.one(
              "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.created_at LIMIT 1",
              [user["id"]]
            )

        assigns = [
          id: room["id"],
          name: Assets.html_escape(room["name"] || ""),
          base: Assets.html_escape(Auth.base(conn)),
          users:
            Enum.map_join(
              if(kind == "direct", do: direct_users, else: users),
              &render_user.(&1, false)
            ),
          selected_users: Enum.map_join(selected, &render_user.(&1, true)),
          unselected_users: Enum.map_join(unselected, &render_user.(&1, false)),
          separator: selected != [] && unselected != [],
          filter: if(length(users) > 20, do: filter(), else: "")
        ]

        title =
          if edit,
            do: "Edit settings for " <> RoomPage.display_name(room, user),
            else: if(kind == "direct", do: "Campfire", else: "New chat room")

        navigation =
          if kind == "direct" && !edit,
            do: "      \n",
            else: nav(back: if(back_room, do: "/rooms/#{back_room["id"]}", else: "/"))

        {conn, html} =
          Page.render(conn, user, data,
            title: Assets.html_escape(title),
            nav: navigation,
            content: content(branch, assigns)
          )

        conn |> put_resp_content_type("text/html") |> send_resp(200, html)
    end
  end

  defp render_user(target, current, kind, edit, admin, selected) do
    branch =
      cond do
        kind == "direct" -> "direct"
        !admin -> "readonly"
        kind == "open" -> "open"
        !edit && target["id"] == current["id"] -> "new_self"
        true -> "closed"
      end

    avatar =
      Mentions.avatar(target, :page)
      |> String.replace("<img aria-hidden=\"true\"", "<img aria-hidden=\"true\" loading=\"lazy\"")

    user_content(branch,
      id: target["id"],
      name: Assets.html_escape(target["name"] || ""),
      value: Assets.html_escape(String.downcase(target["name"] || "")),
      avatar: avatar,
      checked: if(selected, do: " checked=\"checked\"", else: "")
    )
  end

  defp filter,
    do:
      ~s(    <input type="search" id="search" autocorrect="off" autocomplete="off" data-1p-ignore="true" class="input input--transparent full-width" placeholder="Filter…" data-action="input-&gt;filter#filter">) <>
        "\n"

  defp head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")
end
