defmodule Campfire.Boosts do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Broadcasts, Chat, DB, Mentions, MessagesView, Page}
  require EEx
  EEx.function_from_file(:defp, :new_form, "priv/templates/new_boost.html.eex", [:assigns])

  def call(conn, message_id, id \\ nil) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      conn.method not in ["GET", "HEAD"] && !Auth.csrf_valid?(conn, conn.params) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      true ->
        conn = Auth.set_auth_cookie(conn, session)

        message =
          DB.one(
            "SELECT m.* FROM messages m JOIN memberships mm ON mm.room_id=m.room_id WHERE m.id=? AND mm.user_id=?",
            [Chat.integer(message_id), user["id"]]
          )

        if message, do: action(conn, user, message, id), else: send_resp(conn, 404, "")
    end
  end

  defp action(%{method: "POST"} = conn, user, message, nil) do
    case Campfire.Params.required(conn.params, "boost") |> Campfire.Params.permit(["content"]) do
      %{} = attrs ->
        boost = Chat.create_boost(user, message, attrs["content"])
        Broadcasts.boost_create(message, boost)
        Auth.redirect(conn, "/messages/#{message["id"]}/boosts")

      _ ->
        send_resp(conn, 400, "")
    end
  end

  defp action(%{method: "DELETE"} = conn, user, message, id) do
    if boost =
         DB.one("SELECT * FROM boosts WHERE message_id=? AND booster_id=? AND id=?", [
           message["id"],
           user["id"],
           Chat.integer(id)
         ]) do
      Chat.delete_boost(boost, message)
      Broadcasts.boost_remove(message, boost)

      send_resp(conn, 204, "")
    else
      send_resp(conn, 404, "")
    end
  end

  defp action(%{method: "GET"} = conn, user, message, "new") do
    {conn, data} = Auth.csrf_session(conn)

    content =
      new_form(
        id: message["id"],
        key: message["client_message_id"],
        avatar: Mentions.avatar(user, :page),
        name: Assets.html_escape(user["name"])
      )

    {conn, html} = Page.render(conn, user, data, content: content)
    conn |> put_resp_content_type("text/html") |> send_resp(200, html)
  end

  defp action(%{method: "GET"} = conn, user, message, nil) do
    {conn, data} = Auth.csrf_session(conn)
    content = "      " <> MessagesView.render_boosts(message) <> "\n\n\n"
    {conn, html} = Page.render(conn, user, data, content: content)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp action(conn, _, _, _), do: send_resp(conn, 404, "")
end
