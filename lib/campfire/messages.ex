defmodule Campfire.Messages do
  import Plug.Conn
  alias Campfire.{Auth, Broadcasts, Chat, DB, MessagesView, Rails, Webhooks}

  require EEx
  EEx.function_from_file(:defp, :editor, "priv/templates/message_edit.html.eex", [:assigns])

  def call(conn, room_id, id \\ nil, edit \\ false) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      conn.method not in ["GET", "HEAD"] && !Auth.csrf_valid?(conn, conn.params) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        head(conn, 429)

      true ->
        conn = Auth.set_auth_cookie(conn, session)

        if room = Chat.room(user, room_id) do
          if edit, do: edit_page(conn, user, room, id), else: action(conn, user, room, id)
        else
          head(conn, 404)
        end
    end
  end

  defp action(%{method: "GET"} = conn, _user, room, nil) do
    case Chat.messages(room, conn.params) do
      {:error, :not_found} ->
        head(conn, 404)

      [] ->
        send_resp(conn, 204, "")

      messages ->
        # Foreign SQL can change rich text or creator/boost presentation without
        # touching message timestamps. HttpResponse hashes the rendered body.
        conn =
          conn
          |> assign(:controller_validator, true)
          |> put_resp_header("cache-control", "max-age=0, private, must-revalidate")

        {conn, data} = Auth.csrf_session(conn)
        token = Campfire.ResponseCache.mask(Rails.csrf_global(data["_csrf_token"]))

        if json?(conn) do
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(
            200,
            Rails.json(Enum.map(messages, &Chat.present_message(&1, Auth.base(conn))))
          )
        else
          body = MessagesView.render_many(messages, Auth.base(conn), token)

          conn
          |> Auth.set_csrf_session(data)
          |> put_resp_content_type("text/html")
          |> send_resp(200, "\n" <> body)
        end
    end
  end

  defp action(%{method: "POST"} = conn, user, room, nil) do
    attrs =
      Campfire.Params.required(conn.params, "message")
      |> Campfire.Params.permit(~w(body attachment client_message_id))

    case Chat.create_message(user, room, attrs["body"], attrs) do
      message when is_map(message) ->
        Campfire.Attachments.process_message(message)
        Broadcasts.create(room, message, Auth.base(conn), user)
        Webhooks.enqueue(room, message)

        stream =
          ~s(<turbo-stream action="append" target="messages_#{Broadcasts.room_key(room)}"><template>
#{MessagesView.render(message, Auth.base(conn)) |> String.trim_trailing("\n")}</template></turbo-stream>\n)

        conn |> put_resp_content_type("text/vnd.turbo-stream.html") |> send_resp(200, stream)

      {:error, error} ->
        raise error
    end
  end

  defp action(conn, user, room, id) do
    message =
      DB.one("SELECT * FROM messages WHERE room_id=? AND id=?", [room["id"], Chat.integer(id)])

    cond do
      !message ->
        head(conn, 404)

      conn.method not in ["GET", "HEAD"] && !Chat.can_administer?(user, message) ->
        head(conn, 403)

      conn.method == "DELETE" ->
        Chat.delete_message(message)
        Broadcasts.remove(room, message)

        conn
        |> put_resp_content_type("text/vnd.turbo-stream.html")
        |> send_resp(
          200,
          ~s(<turbo-stream action="remove" target="message_#{message["client_message_id"]}"></turbo-stream>\n)
        )

      conn.method in ["PATCH", "PUT"] ->
        attrs =
          Campfire.Params.required(conn.params, "message")
          |> Campfire.Params.permit(~w(body attachment client_message_id))

        message = Chat.update_message(message, attrs["body"], attrs)
        Broadcasts.replace(room, message)
        conn = assign(conn, :message_updated, true)

        if json?(conn),
          do:
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Rails.json(Chat.present_message(message, Auth.base(conn)))),
          else: Auth.redirect(conn, "/rooms/#{room["id"]}/messages/#{message["id"]}")

      conn.method == "GET" && json?(conn) ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Rails.json(Chat.present_message(message, Auth.base(conn))))

      conn.method == "GET" ->
        {conn, data} = Auth.csrf_session(conn)
        token = Campfire.ResponseCache.mask(Rails.csrf_global(data["_csrf_token"]))
        content = "      \n" <> MessagesView.render(message, Auth.base(conn), token) <> "\n\n"
        {conn, html} = Campfire.Page.render(conn, user, data, content: content)
        conn |> put_resp_content_type("text/html") |> send_resp(200, html)

      true ->
        head(conn, 404)
    end
  end

  defp edit_page(conn, user, room, id) do
    message =
      DB.one("SELECT * FROM messages WHERE room_id=? AND id=?", [room["id"], Chat.integer(id)])

    cond do
      !message ->
        head(conn, 404)

      !Chat.can_administer?(user, message) ->
        head(conn, 403)

      true ->
        text =
          DB.one(
            "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
            [message["id"]]
          )

        body = if text, do: text["body"] || "", else: ""
        path = "/rooms/#{room["id"]}/messages/#{message["id"]}"
        {conn, data} = Auth.csrf_session(conn)

        content =
          editor(
            id: message["id"],
            room_id: room["id"],
            client_id: Campfire.Assets.html_escape(message["client_message_id"]),
            base: Auth.base(conn),
            body: Campfire.Assets.html_escape(body),
            patch_token:
              Campfire.ResponseCache.mask(Rails.csrf_form(data["_csrf_token"], path, "PATCH")),
            delete_token:
              Campfire.ResponseCache.mask(Rails.csrf_form(data["_csrf_token"], path, "DELETE"))
          )

        {conn, html} = Campfire.Page.render(conn, user, data, content: content)
        conn |> put_resp_content_type("text/html") |> send_resp(200, html)
    end
  end

  defp json?(conn),
    do:
      conn.params["format"] == "json" ||
        Enum.any?(get_req_header(conn, "accept"), &String.contains?(&1, "application/json"))

  defp head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")
end
