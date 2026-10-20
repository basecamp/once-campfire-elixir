defmodule Campfire.Router do
  use Plug.Router
  alias Campfire.{Auth, Chat, DB, Rails}
  plug(Campfire.RequestURL)
  plug(Campfire.PublicFiles)
  plug(Plug.Head)
  plug(Campfire.HttpResponse)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    body_reader: {Campfire.Body, :read, []}
  )

  plug(Plug.MethodOverride)
  plug(:request_context)
  plug(:account_format)
  plug(Campfire.RouteRecognition)
  plug(:match)
  plug(Campfire.CacheEpoch)
  plug(Campfire.BrowserGuard)
  plug(:response_cache)
  plug(:dispatch)

  # The route table lives in priv/routes_dispatch.exs: the same Plug.Router macro calls,
  # evaluated in this module so path params, HEAD handling and matching order are unchanged.
  # The route bodies use the router's aliases (`DB.one`, `Auth.redirect`, ...), so the injected
  # scope carries them along with the macros that `use Plug.Router` imports.
  Code.eval_quoted(
    quote do
      alias Campfire.{Auth, Chat, DB, Rails}
      import Plug.Router
      import Plug.Conn

      unquote(
        Code.string_to_quoted!(File.read!("priv/routes_dispatch.exs"),
          file: "priv/routes_dispatch.exs"
        )
      )
    end,
    [],
    __ENV__
  )

  defp account_format(%{path_info: ["account." <> format], method: method} = conn, _)
       when method in ["PUT", "PATCH"] do
    %{conn | path_info: ["account"], params: Map.put(conn.params, "format", format)}
  end

  defp account_format(conn, _), do: conn

  defp request_context(conn, _) do
    Process.put(:campfire_request_host, conn.host)
    Process.put(:campfire_request_base, Auth.base(conn))
    conn
  end

  defp bot_boost_request(conn, room_id, bot_key, message_id, id) do
    {conn, user, method} = Auth.bot_or_session(conn, bot_key)

    cond do
      is_nil(user) ->
        Auth.request_authentication(conn)

      method == :session and conn.method not in ["GET", "HEAD"] and
          not Auth.request_allowed?(conn) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        rails_head(conn, 429)

      true ->
        room = Chat.room(user, room_id)

        message =
          if room,
            do:
              DB.one("SELECT * FROM messages WHERE room_id=? AND id=?", [
                room["id"],
                Chat.integer(message_id)
              ]),
            else: nil

        if message, do: bot_boost_action(conn, user, message, id), else: rails_head(conn, 404)
    end
  end

  defp bot_boost_action(%{method: "POST"} = conn, user, message, nil) do
    {:ok, body, conn} = Campfire.Body.read_all(conn)

    if Chat.present?(body) do
      case Chat.create_boost(user, message, body) do
        {:error, error} ->
          raise error

        boost ->
          Campfire.Broadcasts.boost_create(message, boost)

          if Enum.any?(Campfire.ResponseFormats.requested(conn), &(&1 in ["json", "all"])),
            do: json(conn, 201, Chat.present_boost(boost, message, base(conn))),
            else: Campfire.HttpResponse.error(conn, 500)
      end
    else
      rails_head(conn, 422)
    end
  end

  defp bot_boost_action(%{method: "DELETE"} = conn, user, message, id) do
    boost =
      DB.one("SELECT * FROM boosts WHERE message_id=? AND id=? AND booster_id=?", [
        message["id"],
        Chat.integer(id),
        user["id"]
      ])

    if boost do
      :ok = Chat.delete_boost(boost, message)
      Campfire.Broadcasts.boost_remove(message, boost)
      send_resp(conn, 204, "")
    else
      rails_head(conn, 404)
    end
  end

  defp bot_boost_action(conn, _, _, _), do: rails_head(conn, 404)

  defp bot_request(conn, room_id, bot_key, id) do
    conn = fetch_query_params(conn)

    {conn, user, method} = Auth.bot_or_session(conn, bot_key)

    cond do
      is_nil(user) ->
        Auth.request_authentication(conn)

      method == :session and conn.method not in ["GET", "HEAD"] and
          not Auth.request_allowed?(conn) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        rails_head(conn, 429)

      true ->
        case Chat.room(user, room_id) do
          nil -> rails_head(conn, 404)
          room -> bot_action(conn, user, room, id)
        end
    end
  end

  defp bot_action(%{method: "GET"} = conn, _user, room, nil) do
    case Chat.messages(room, conn.query_params) do
      {:error, :not_found} ->
        record_not_found(conn)

      messages ->
        [%{"count" => count}] =
          DB.query("SELECT COUNT(*) AS count FROM messages WHERE room_id=?", [room["id"]])

        conn =
          put_resp_header(conn, "x-total-count", to_string(count)) |> pagination(room, messages)

        if "html" in Campfire.ResponseFormats.requested(conn) do
          {conn, data} = Auth.browser_session(conn)

          body =
            "\n" <> Enum.map_join(messages, &Campfire.MessagesView.render(&1, base(conn)))

          conn
          |> Auth.set_browser_session(data)
          |> put_resp_content_type("text/html")
          |> send_resp(200, body)
        else
          json(conn, 200, Enum.map(messages, &Chat.present_message(&1, base(conn))))
        end
    end
  end

  defp bot_action(%{method: "POST"} = conn, user, room, nil) do
    {:ok, body, conn} = Campfire.Body.read_all(conn)

    attachment = conn.params["attachment"]

    if Chat.present?(body) || attachment do
      case Chat.create_message(user, room, if(attachment, do: nil, else: body), %{
             "attachment" => attachment
           }) do
        {:error, error} ->
          raise error

        m ->
          Campfire.Attachments.process_message(m)
          :ok = Campfire.Broadcasts.create(room, m, base(conn), user)
          :ok = Campfire.Webhooks.enqueue(room, m)

          put_resp_header(conn, "location", base(conn) <> "/messages/#{m["id"]}")
          |> put_resp_header("content-type", Campfire.ResponseFormats.head_type(conn))
          |> send_resp(201, "")
      end
    else
      rails_head(conn, 422)
    end
  end

  defp bot_action(conn, user, room, id) when not is_nil(id) do
    case DB.one("SELECT * FROM messages WHERE room_id=? AND id=?", [room["id"], Chat.integer(id)]) do
      nil ->
        record_not_found(conn)

      m ->
        if Chat.can_administer?(user, m) do
          case conn.method do
            method when method in ["PATCH", "PUT"] ->
              {:ok, body, conn} = Campfire.Body.read_all(conn)

              attrs = Map.take(conn.params, ["attachment"])
              body = if Map.has_key?(attrs, "attachment"), do: nil, else: body

              case Chat.update_message(m, body, attrs) do
                {:error, _} ->
                  rails_head(conn, 422)

                m ->
                  Campfire.Broadcasts.replace(room, m)

                  if "html" in Campfire.ResponseFormats.requested(conn),
                    do: Auth.redirect(conn, "/rooms/#{room["id"]}/messages/#{m["id"]}"),
                    else: json(conn, 200, Chat.present_message(m, base(conn)))
              end

            "DELETE" ->
              :ok = Chat.delete_message(m)
              Campfire.Broadcasts.remove(room, m)
              send_resp(conn, 204, "")

            _ ->
              rails_head(conn, 404)
          end
        else
          rails_head(conn, 403)
        end
    end
  end

  defp bot_action(conn, _, _, _), do: rails_head(conn, 404)
  defp pagination(conn, _, []), do: conn

  defp pagination(conn, room, messages) do
    {param, m, op} =
      if Chat.present?(conn.query_params["after"]),
        do: {"after", List.last(messages), ">"},
        else: {"before", List.first(messages), "<"}

    if DB.one("SELECT id FROM messages WHERE room_id=? AND created_at #{op} ? LIMIT 1", [
         room["id"],
         m["created_at"]
       ]) do
      put_resp_header(
        conn,
        "link",
        "<#{base(conn)}#{String.replace_suffix(conn.request_path, ".#{conn.params["format"]}", "")}?#{param}=#{m["id"]}>; rel=\"next\""
      )
    else
      conn
    end
  end

  defp base(conn),
    do:
      "#{conn.scheme}://#{conn.host}" <> if(conn.port in [80, 443], do: "", else: ":#{conn.port}")

  defp json(conn, status, value),
    do: conn |> put_resp_content_type("application/json") |> send_resp(status, Rails.json(value))

  defp rails_head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")

  defp record_not_found(conn),
    do:
      conn
      |> put_resp_header("content-type", "application/json; charset=UTF-8")
      |> send_resp(404, ~s({"status":404,"error":"Not Found"}))

  defp response_cache(conn, _), do: Campfire.ResponseCache.call(conn, [])
end
