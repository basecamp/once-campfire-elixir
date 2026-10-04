defmodule Campfire.Page do
  alias Campfire.{Assets, Auth, DB, Rails}
  require EEx
  EEx.function_from_file(:defp, :layout, "priv/templates/application.html.eex", [:assigns])

  def render(conn, user, data, assigns),
    do: {Auth.set_csrf_session(conn, Map.delete(data, "flash")), html(conn, user, data, assigns)}

  @doc "The page body alone; `render/4` also sets the CSRF session cookie."
  def html(conn, user, data, assigns) do
    account = DB.one("SELECT * FROM accounts LIMIT 1") || %{}

    defaults = [
      current_user_meta:
        if(user,
          do:
            ~s(<meta name="current-user-id" content="#{user["id"]}" /><meta name="current-user-name" content="#{Assets.html_escape(user["name"])}" />),
          else: ""
        ),
      admin: user && user["role"] == 1,
      account_has_logo: !!Campfire.Attachments.find("Account", account["id"], "logo"),
      title: "Campfire",
      flash: Campfire.Flash.render(data),
      custom_styles: custom_styles(account),
      body_class: "",
      head: "    ",
      nav: "      \n",
      content: "",
      footer: "        \n",
      sidebar: "      \n",
      meta_token: Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"])),
      vapid: Assets.html_escape(System.get_env("VAPID_PUBLIC_KEY", "")),
      account_version:
        (account["updated_at"] || "") |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14)
    ]

    merged = Keyword.merge(defaults, assigns)

    if Plug.Conn.get_req_header(conn, "turbo-frame") != [] do
      content = String.replace_suffix(merged[:content], "\n\n", "\n")

      content =
        if String.starts_with?(content, "      "),
          do: String.replace_prefix(content, "      ", "    "),
          else: "    " <> content

      "<html>\n  <head>\n    <meta name=\"csrf-param\" content=\"authenticity_token\" />\n<meta name=\"csrf-token\" content=\"#{merged[:meta_token]}\" />\n#{merged[:head]}\n  </head>\n  <body>\n#{content}  </body>\n</html>\n"
    else
      layout(merged)
    end
  end

  @doc "Request facts a cached page depends on besides its route and database inputs."
  def cache_context(conn, data) do
    {data["_csrf_token"], Auth.base(conn), Plug.Conn.get_req_header(conn, "turbo-frame"),
     Plug.Conn.get_req_header(conn, "user-agent")}
  end

  def custom_styles(account) do
    if is_nil(account["custom_styles"]),
      do: "",
      else: ~s(<style data-turbo-track="reload">#{account["custom_styles"]}</style>)
  end
end
