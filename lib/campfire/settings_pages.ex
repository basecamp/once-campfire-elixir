defmodule Campfire.SettingsPages do
  import Plug.Conn
  alias Campfire.{Assets, Attachments, Auth, Chat, DB, Page, Rails, Storage}
  require EEx
  EEx.function_from_file(:defp, :styles, "priv/templates/custom_styles.html.eex", [:assigns])

  EEx.function_from_file(:defp, :styles_nav, "priv/templates/custom_styles_nav.html.eex", [
    :_assigns
  ])

  EEx.function_from_file(:defp, :new_bot, "priv/templates/new_bot.html.eex", [:assigns])
  EEx.function_from_file(:defp, :new_bot_nav, "priv/templates/new_bot_nav.html.eex", [:_assigns])
  EEx.function_from_file(:defp, :edit_bot, "priv/templates/edit_bot.html.eex", [:assigns])

  EEx.function_from_file(:defp, :edit_bot_nav, "priv/templates/edit_bot_nav.html.eex", [:_assigns])

  def call(conn, action, id \\ nil) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      user["role"] != 1 ->
        head(conn, 403)

      true ->
        {conn, data} = Auth.csrf_session(Auth.set_auth_cookie(conn, session))
        show(conn, user, data, action, id)
    end
  end

  defp show(conn, user, data, :custom_styles, _) do
    account = DB.one("SELECT * FROM accounts LIMIT 1")

    body =
      styles(
        base: Assets.html_escape(Auth.base(conn)),
        styles: Assets.html_escape(account["custom_styles"] || ""),
        form_token: token(data, "/account/custom_styles", "PATCH")
      )

    page(conn, user, data, "Custom styles", styles_nav([]), body)
  end

  defp show(conn, user, data, :new_bot, _) do
    body =
      new_bot(
        avatar_src: Assets.path("default-bot-avatar.svg"),
        webhook_value: "",
        form_token: token(data, "/account/bots", "POST")
      )

    page(conn, user, data, "New chat bot", new_bot_nav([]), body)
  end

  defp show(conn, user, data, :edit_bot, id) do
    if bot = DB.one("SELECT * FROM users WHERE id=? AND role=2 AND status=0", [Chat.integer(id)]) do
      path = "/account/bots/#{bot["id"]}"
      avatar = Attachments.find("User", bot["id"], "avatar")
      hook = DB.one("SELECT url FROM webhooks WHERE user_id=?", [bot["id"]])

      body =
        edit_bot(
          bot_id: bot["id"],
          name: Assets.html_escape(bot["name"]),
          avatar_src:
            Assets.html_escape(
              if(avatar,
                do: Auth.base(conn) <> Storage.blob_path(avatar),
                else: Assets.path("default-bot-avatar.svg")
              )
            ),
          webhook_value:
            if(hook && hook["url"], do: ~s( value="#{Assets.html_escape(hook["url"])}"), else: ""),
          form_token: token(data, path, "PATCH"),
          delete_token: token(data, path, "DELETE"),
          key_token: token(data, path <> "/key", "PUT")
        )

      page(conn, user, data, "Edit bot", edit_bot_nav([]), body)
    else
      head(conn, 404)
    end
  end

  defp page(conn, user, data, title, nav, content) do
    {conn, html} = Page.render(conn, user, data, title: title, nav: nav, content: content)
    conn |> put_resp_content_type("text/html") |> send_resp(200, html)
  end

  defp token(data, path, method),
    do: Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], path, method))

  defp head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")
end
