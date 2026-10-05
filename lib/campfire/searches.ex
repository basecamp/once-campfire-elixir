defmodule Campfire.Searches do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Chat, DB, MessagesView}
  require EEx
  EEx.function_from_file(:defp, :nav, "priv/templates/search_nav.html.eex", [:assigns])
  EEx.function_from_file(:defp, :content, "priv/templates/search_content.html.eex", [:assigns])
  EEx.function_from_file(:defp, :footer, "priv/templates/search_footer.html.eex", [:assigns])
  EEx.function_from_file(:defp, :sidebar, "priv/templates/search_sidebar.html.eex", [:assigns])

  def call(conn) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      conn.method != "GET" && !Auth.csrf_valid?(conn, conn.params) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      true ->
        action(Auth.set_auth_cookie(conn, session), user)
    end
  end

  def query(nil), do: nil
  def query(value), do: String.replace(value, ~r/[^\p{L}\p{M}\p{N}\p{Pc}]/u, " ")

  defp action(%{method: "DELETE"} = conn, user) do
    DB.query("DELETE FROM searches WHERE user_id=?", [user["id"]])
    Auth.redirect(conn, "/searches")
  end

  defp action(%{method: "POST"} = conn, user) do
    q = query(conn.params["q"])
    now = Chat.timestamp()

    DB.transaction(fn sql ->
      case sql.("SELECT id FROM searches WHERE user_id=? AND query=? LIMIT 1", [user["id"], q]) do
        [search] ->
          sql.("UPDATE searches SET updated_at=? WHERE id=?", [now, search["id"]])

        [] ->
          sql.("INSERT INTO searches (user_id,query,created_at,updated_at) VALUES (?,?,?,?)", [
            user["id"],
            q,
            now,
            now
          ])

          sql.(
            "DELETE FROM searches WHERE user_id=? AND id NOT IN (SELECT id FROM searches WHERE user_id=? ORDER BY updated_at DESC LIMIT 10)",
            [user["id"], user["id"]]
          )
      end
    end)

    Auth.redirect(
      conn,
      "/searches" <> if(is_nil(q), do: "", else: "?q=" <> URI.encode_www_form(q))
    )
  end

  defp action(%{method: "GET"} = conn, user) do
    raw = conn.params["q"]
    q = query(raw)

    messages =
      if Chat.present?(q),
        do:
          DB.cached(
            "SELECT * FROM (SELECT m.* FROM messages m JOIN message_search_index idx ON m.id=idx.rowid JOIN memberships mm ON mm.room_id=m.room_id WHERE mm.user_id=? AND idx.body MATCH ? ORDER BY m.created_at DESC LIMIT 100) ORDER BY created_at",
            [user["id"], q],
            ~w(messages message_search_index memberships)
          ),
        else: []

    recents =
      DB.cached(
        "SELECT * FROM searches WHERE user_id=? ORDER BY updated_at DESC",
        [user["id"]],
        ~w(searches)
      )

    {conn, data} = Auth.csrf_session(conn)
    return_room = if conn.cookies["last_room"], do: Chat.room(user, conn.cookies["last_room"])

    return_room =
      return_room ||
        DB.cached_one(
          "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.created_at LIMIT 1",
          [user["id"]],
          ~w(rooms memberships)
        )

    links =
      Enum.map_join(recents, fn search ->
        ~s(      <a class="align-center gap room btn txt-nowrap" href="/searches?q=#{Assets.html_escape(URI.encode_www_form(search["query"]))}">\n        <span class="overflow-ellipsis">“#{Assets.html_escape(search["query"])}”</span>\n</a>)
      end) <> if(recents == [], do: "", else: "\n")

    # Messages are spliced in after layout so their cached gzip pieces are reused.
    marker = "<!--campfire-messages-" <> Base.encode16(:crypto.strong_rand_bytes(16)) <> "-->"
    fragments = MessagesView.render_parts(messages, Auth.base(conn))

    assigns = [
      query: if(Chat.present?(q), do: Assets.html_escape(q)),
      raw_query: if(raw, do: Assets.html_escape(raw)),
      count: length(messages),
      base: Auth.base(conn),
      has_recents: recents != [],
      recent_links: links,
      return_room: return_room["id"],
      messages: marker
    ]

    {conn, html} =
      Campfire.Page.render(conn, user, data,
        title: "Search",
        body_class: "sidebar searches",
        nav: nav(assigns),
        content: content(assigns),
        footer: footer(assigns),
        sidebar: sidebar(assigns)
      )

    {body, parts} = Campfire.HttpCompression.splice(html, marker, fragments)

    conn
    |> put_resp_content_type("text/html")
    |> assign(:page_parts, parts)
    |> send_resp(200, body)
  end
end
