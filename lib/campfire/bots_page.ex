defmodule Campfire.BotsPage do
  import Plug.Conn
  alias Campfire.{Assets, Auth, DB, Mentions, Page}
  require EEx
  EEx.function_from_file(:defp, :index, "priv/templates/bots.html.eex", [:assigns])
  EEx.function_from_file(:defp, :nav, "priv/templates/bots_nav.html.eex", [:_assigns])
  EEx.function_from_file(:defp, :row, "priv/templates/bot_row.html.eex", [:assigns])
  EEx.function_from_file(:defp, :room_row, "priv/templates/bot_room.html.eex", [:assigns])

  def show(conn) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      user["role"] != 1 ->
        conn |> put_resp_header("content-type", "text/html") |> send_resp(403, "")

      true ->
        {conn, data} = Auth.csrf_session(Auth.set_auth_cookie(conn, session))
        bots = DB.query("SELECT * FROM users WHERE role=2 AND status=0 ORDER BY LOWER(name)")
        content = index(bots: Enum.map_join(bots, &render_bot(&1, conn)))

        {conn, html} =
          Page.render(conn, user, data, title: "Chat bots", nav: nav([]), content: content)

        conn |> put_resp_content_type("text/html") |> send_resp(200, html)
    end
  end

  defp render_bot(bot, conn) do
    rooms =
      DB.query(
        "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? AND r.type!='Rooms::Direct' ORDER BY LOWER(r.name)",
        [bot["id"]]
      )

    rendered =
      Enum.map_join(rooms, fn room ->
        url = Auth.base(conn) <> "/rooms/#{room["id"]}/#{bot["id"]}-#{bot["bot_token"]}/messages"

        room_row(
          name: Assets.html_escape(room["name"]),
          text: Assets.html_escape("curl -d 'Hello!' " <> url),
          upload: Assets.html_escape(~s(curl -F "attachment=@/path/to/file" ) <> url)
        )
      end)

    avatar =
      Mentions.avatar(bot, :page)
      |> String.replace("<img aria-hidden=\"true\"", "<img aria-hidden=\"true\" loading=\"lazy\"")

    row(id: bot["id"], name: Assets.html_escape(bot["name"]), avatar: avatar, rooms: rendered)
  end
end
