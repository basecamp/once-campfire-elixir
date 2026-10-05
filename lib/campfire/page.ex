defmodule Campfire.Page do
  alias Campfire.{Assets, Auth, DB}
  require EEx
  EEx.function_from_file(:defp, :layout, "priv/templates/application.html.eex", [:assigns])

  # The account, whether it has a logo (every layout shows it) and the original room (the room
  # page's invitation), in one query.
  @account_sql """
  SELECT a.*, EXISTS(SELECT 1 FROM active_storage_attachments t JOIN active_storage_blobs b ON b.id=t.blob_id WHERE t.record_type='Account' AND t.record_id=a.id AND t.name='logo') AS "page.has_logo", (SELECT id FROM rooms ORDER BY created_at LIMIT 1) AS "page.original_room_id" FROM accounts a LIMIT 1
  """

  @doc "The account row for a page; pass it as `account:` to `render/4` to avoid a second query."
  def account, do: DB.one(@account_sql)

  def render(conn, user, data, assigns) do
    {account, assigns} = Keyword.pop_lazy(assigns, :account, &account/0)
    {has_logo, account} = Map.pop(account || %{}, "page.has_logo")
    account = Map.delete(account, "page.original_room_id")

    defaults = [
      current_user_meta:
        if(user,
          do:
            ~s(<meta name="current-user-id" content="#{user["id"]}" /><meta name="current-user-name" content="#{Assets.html_escape(user["name"])}" />),
          else: ""
        ),
      admin: user && user["role"] == 1,
      account_has_logo: has_logo == 1,
      title: "Campfire",
      flash: Campfire.Flash.render(data),
      custom_styles: custom_styles(account),
      body_class: "",
      head: "    ",
      nav: "      \n",
      content: "",
      footer: "        \n",
      sidebar: "      \n",
      vapid: Campfire.Release.vapid_public_key(),
      account_version:
        (account["updated_at"] || "") |> Campfire.Chat.digits() |> String.slice(0, 14)
    ]

    merged = Keyword.merge(defaults, assigns)

    html =
      if Plug.Conn.get_req_header(conn, "turbo-frame") != [] do
        content = String.replace_suffix(merged[:content], "\n\n", "\n")

        content =
          if String.starts_with?(content, "      "),
            do: String.replace_prefix(content, "      ", "    "),
            else: "    " <> content

        "<html>\n  <head>\n    <meta name=\"csrf-param\" content=\"authenticity_token\" />\n<meta name=\"csrf-token\" content=\"\" />\n#{merged[:head]}\n  </head>\n  <body>\n#{content}  </body>\n</html>\n"
      else
        layout(merged)
      end

    {finish_session(conn, data), html}
  end

  @doc "The session update rendering a page makes (its flash is shown, so it is dropped)."
  def finish_session(conn, data), do: Auth.set_csrf_session(conn, Map.delete(data, "flash"))

  def custom_styles(account) do
    if is_nil(account["custom_styles"]),
      do: "",
      else: ~s(<style data-turbo-track="reload">#{account["custom_styles"]}</style>)
  end
end
