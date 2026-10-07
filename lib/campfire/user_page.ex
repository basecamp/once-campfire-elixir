defmodule Campfire.UserPage do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Chat, DB, Page, ProfilePage}
  require EEx

  for branch <-
        ~w(admin_self admin_active admin_banned member_self member_active member_banned deactivated bot_active bot_deactivated) do
    EEx.function_from_file(
      :defp,
      String.to_atom(branch),
      "priv/templates/user_#{branch}.html.eex",
      [:assigns]
    )

    defp content(unquote(branch), assigns), do: unquote(String.to_atom(branch))(assigns)
  end

  EEx.function_from_file(:defp, :self_nav, "priv/templates/user_nav_self.html.eex", [:assigns])
  EEx.function_from_file(:defp, :other_nav, "priv/templates/user_nav_other.html.eex", [:assigns])

  def show(conn, id) do
    {conn, current, session} = Auth.session_user(conn)
    target = DB.one("SELECT * FROM users WHERE id=?", [Chat.integer(id)])

    cond do
      !current ->
        Auth.request_authentication(conn)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      !target ->
        Campfire.HttpResponse.exception(conn, 404, Campfire.Assets.read("public/404.html"))

      true ->
        {conn, data} = Auth.csrf_session(Auth.set_auth_cookie(conn, session))
        self = current["id"] == target["id"]
        admin = current["role"] == 1

        branch =
          cond do
            target["role"] == 2 ->
              if target["status"] == 0, do: "bot_active", else: "bot_deactivated"

            target["status"] == 1 ->
              "deactivated"

            target["status"] == 2 ->
              if admin, do: "admin_banned", else: "member_banned"

            admin ->
              if self, do: "admin_self", else: "admin_active"

            true ->
              if self, do: "member_self", else: "member_active"
          end

        assigns = [
          id: target["id"],
          name: Assets.html_escape(target["name"] || ""),
          email: Assets.html_escape(target["email_address"] || ""),
          bio: Assets.html_escape(target["bio"] || ""),
          avatar_src: ProfilePage.avatar_path(target),
          transfer: ProfilePage.transfer_link(conn, target, self)
        ]

        referer = List.first(get_req_header(conn, "referer"))

        back =
          if is_nil(referer) || referer == Auth.base(conn) <> conn.request_path,
            do: "/",
            else: referer

        nav =
          if self,
            do: self_nav(back: Assets.html_escape(back)),
            else: other_nav(back: Assets.html_escape(back))

        {conn, html} =
          Page.render(conn, current, data,
            title: Assets.html_escape(target["name"] || ""),
            nav: nav,
            content: content(branch, assigns)
          )

        conn |> put_resp_content_type("text/html") |> send_resp(200, html)
    end
  end
end
