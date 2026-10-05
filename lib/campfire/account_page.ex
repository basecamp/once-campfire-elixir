defmodule Campfire.AccountPage do
  import Plug.Conn
  alias Campfire.{Assets, Attachments, Auth, Chat, DB, Mentions, Page}
  require EEx

  for {function, file} <- [
        {:account, "account"},
        {:readonly, "account_readonly"},
        {:nav, "account_nav"},
        {:readonly_nav, "account_readonly_nav"},
        {:footer, "account_footer"},
        {:user_row, "account_user"},
        {:role_form, "account_user_role"},
        {:delete_form, "account_user_delete"},
        {:self_link, "account_user_self"},
        {:logo_delete, "account_logo_delete"}
      ] do
    EEx.function_from_file(
      :defp,
      function,
      "priv/templates/#{file}.html.eex",
      if(function == :self_link, do: [:_assigns], else: [:assigns])
    )
  end

  def show(conn) do
    {conn, user, session} = Auth.session_user(conn)

    if user do
      conn = Auth.set_auth_cookie(conn, session)
      {conn, data} = Auth.csrf_session(conn)
      account = DB.one("SELECT * FROM accounts LIMIT 1")
      admin = user["role"] == 1

      users =
        DB.query(
          "SELECT * FROM users WHERE role!=2 AND status IN (#{if admin, do: "0,2", else: "0"}) ORDER BY LOWER(name)"
        )

      {administrators, members} = Enum.split_with(users, &(&1["role"] == 1))
      invitation = Auth.base(conn) <> "/join/" <> account["join_code"]
      version = Campfire.Chat.digits(account["updated_at"]) |> String.slice(0, 14)
      settings = Jason.decode!(account["settings"] || "{}")
      restriction = settings["restrict_room_creation_to_administrators"]

      back =
        (conn.cookies["last_room"] && Chat.room(user, conn.cookies["last_room"])) ||
          DB.one(
            "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.created_at LIMIT 1",
            [user["id"]]
          )

      assigns = [
        account_id: account["id"],
        name: Assets.html_escape(account["name"]),
        account_version: version,
        invite_url: Assets.html_escape(invitation),
        invite_id: Base.url_encode64(invitation),
        back: if(back, do: "/rooms/#{back["id"]}", else: "/"),
        restricted: restriction,
        next_restriction: if(restriction, do: "false", else: "true"),
        administrators: Enum.map_join(administrators, &render_user(&1, user)),
        members: Enum.map_join(members, &render_user(&1, user)),
        separator: administrators != [] && members != [],
        next_page: if(length(users) > 500, do: next_page(2), else: ""),
        delete_logo:
          if(Attachments.find("Account", account["id"], "logo"),
            do: logo_delete(account_version: version),
            else: ""
          ),
        version: Assets.html_escape(Campfire.Release.version())
      ]

      content = if admin, do: account(assigns), else: readonly(assigns)
      navigation = if admin, do: nav(assigns), else: readonly_nav(assigns)

      {conn, html} =
        Page.render(conn, user, data,
          title: "Account settings",
          content: content,
          nav: navigation,
          footer: footer(assigns)
        )

      conn |> put_resp_content_type("text/html") |> send_resp(200, html)
    else
      Auth.request_authentication(conn)
    end
  end

  def index(conn) do
    {conn, user, session} = Auth.session_user(conn)

    if user do
      conn = Auth.set_auth_cookie(conn, session)

      if Enum.any?(Campfire.ResponseFormats.requested(conn), &(&1 in ["turbo_stream", "all"])) do
        {conn, data} = Auth.csrf_session(conn)
        page = page_number(conn.params["page"])
        count = DB.one("SELECT COUNT(*) AS count FROM users WHERE status=0 AND role!=2")["count"]

        records =
          DB.query(
            "SELECT * FROM users WHERE status=0 AND role!=2 ORDER BY LOWER(name) LIMIT 500 OFFSET ?",
            [(page - 1) * 500]
          )

        rows = Enum.map_join(records, &render_user(&1, user))

        body =
          ~s(<turbo-stream action="replace" target="next_page_container"><template>#{rows}</template></turbo-stream>\n\n) <>
            if(page == max(div(count + 499, 500), 1),
              do: "",
              else:
                ~s(  <turbo-stream action="append" target="account_users"><template>#{next_page(page + 1)}</template></turbo-stream>\n)
            )

        conn =
          if conn.params["format"] == "turbo_stream",
            do: conn,
            else: put_resp_header(conn, "vary", "Accept")

        conn
        |> Auth.set_csrf_session(data)
        |> put_resp_content_type("text/vnd.turbo-stream.html")
        |> send_resp(200, body)
      else
        Campfire.HttpResponse.error(conn, 406)
      end
    else
      Auth.request_authentication(conn)
    end
  end

  defp page_number(param) do
    case Integer.parse(to_string(param || "")) do
      {number, _} when number > 0 -> number
      _ -> 1
    end
  end

  defp next_page(page),
    do:
      ~s(<turbo-frame loading="lazy" class="flex center" id="next_page_container" src="/account/users.turbo_stream?page=#{page}">\n  <div class="spinner center"></div>\n</turbo-frame>)

  def render_user(target, current) do
    self = target["id"] == current["id"]
    admin = target["role"] == 1

    attrs = [
      id: target["id"],
      name: Assets.html_escape(target["name"]),
      self: self,
      admin: admin,
      role: if(admin, do: "Administrator", else: "Member")
    ]

    controls =
      if current["role"] == 1 && target["status"] == 0 do
        role_form(attrs) <>
          if(self, do: "", else: delete_form(attrs))
      else
        ""
      end

    controls = controls <> if(self, do: self_link([]), else: "")

    avatar =
      Mentions.avatar(target, :page)
      |> String.replace("<img aria-hidden=\"true\"", "<img aria-hidden=\"true\" loading=\"lazy\"")

    user_row(
      attrs ++
        [
          banned: if(target["status"] == 2, do: "banned", else: ""),
          avatar: avatar,
          controls: controls
        ]
    )
  end
end
