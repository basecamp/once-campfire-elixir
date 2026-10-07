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
  plug(Campfire.BrowserGuard)
  plug(:response_cache)
  plug(:dispatch)

  get("/", do: Campfire.Navigation.welcome(conn))
  get("/rooms/:room_id/@:message_id", do: Campfire.RoomPage.show(conn, room_id, message_id))
  get("/rooms/opens/new", do: Campfire.RoomForms.show(conn, "open"))
  get("/rooms/opens/:id/edit", do: Campfire.RoomForms.show(conn, "open", id))
  get("/rooms/closeds/new", do: Campfire.RoomForms.show(conn, "closed"))
  get("/rooms/closeds/:id/edit", do: Campfire.RoomForms.show(conn, "closed", id))
  get("/rooms/directs/new", do: Campfire.RoomForms.show(conn, "direct"))
  get("/rooms/directs/:id/edit", do: Campfire.RoomForms.show(conn, "direct", id))
  get("/rooms/directs/:id", do: Campfire.Navigation.direct_room(conn, id))
  get("/rooms/opens/:id", do: Campfire.Navigation.shared_room(conn, id))
  get("/rooms/closeds/:id", do: Campfire.Navigation.shared_room(conn, id))
  get("/rooms/:id", do: Campfire.RoomPage.show(conn, id))
  get("/rooms", do: Campfire.Navigation.rooms_index(conn))

  get("/rooms/:room_id/refresh", do: Campfire.Refresh.show(conn, room_id))

  get("/searches", do: Campfire.Searches.call(conn))
  post("/searches", do: Campfire.Searches.call(conn))
  delete("/searches/clear", do: Campfire.Searches.call(conn))

  post("/unfurl_link", do: Campfire.UnfurlLinks.create(conn))

  get("/autocompletable/users", do: Campfire.Autocomplete.index(conn))
  get("/rooms/:room_id/involvement", do: Campfire.Involvement.show(conn, room_id))

  get("/users/:id", do: Campfire.UserPage.show(conn, id))
  get("/users/:user_id/sidebar", do: Campfire.Sidebar.show(conn))

  delete("/account/logo", do: Campfire.Admin.call(conn, :destroy_logo))
  delete("/users/:user_id/avatar", do: Campfire.Admin.call(conn, :destroy_avatar))
  get("/account/logo", do: Campfire.Images.logo(conn))
  get("/users/:token/avatar", do: Campfire.Images.avatar(conn, token))

  get("/cable", do: Campfire.Cable.upgrade(conn))

  get("/qr_code/:id", do: Campfire.QR.show(conn, id))

  get("/up",
    do:
      send_resp(
        put_resp_content_type(conn, "text/html"),
        200,
        "<!DOCTYPE html><html><body style=\"background-color: green\"></body></html>"
      )
  )

  get("/webmanifest", do: Campfire.Pwa.endpoint(conn, :manifest))
  get("/service-worker", do: Campfire.Pwa.endpoint(conn, :worker))

  get "/webmanifest.json" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Campfire.Assets.manifest(base(conn)))
  end

  get "/service-worker.js" do
    conn
    |> put_resp_content_type("text/javascript")
    |> send_resp(200, Campfire.Assets.read("pwa/service_worker.js"))
  end

  match("/rooms/:room_id/:bot_key/messages", do: bot_request(conn, room_id, bot_key, nil))
  match("/rooms/:room_id/:bot_key/messages/:id", do: bot_request(conn, room_id, bot_key, id))

  match "/rooms/:room_id/:bot_key/messages/:message_id/boosts" do
    bot_boost_request(conn, room_id, bot_key, message_id, nil)
  end

  match "/rooms/:room_id/:bot_key/messages/:message_id/boosts/:id" do
    bot_boost_request(conn, room_id, bot_key, message_id, id)
  end

  get "/session/new" do
    if DB.one("SELECT id FROM users LIMIT 1"),
      do: Campfire.Sessions.login_page(conn, conn.params),
      else: Auth.redirect(conn, "/first_run")
  end

  get("/join/:code", do: Campfire.Signup.call(conn, code))
  post("/join/:code", do: Campfire.Signup.call(conn, code))

  get("/first_run", do: Campfire.Sessions.first_run_page(conn))
  post("/first_run", do: Campfire.Sessions.first_run_create(conn, conn.params))

  post("/session", do: Campfire.Sessions.create(conn, conn.params))
  delete("/session", do: Campfire.Sessions.destroy(conn, conn.params))
  get("/session/transfers/:id", do: Campfire.Sessions.transfer_page(conn, id))
  put("/session/transfers/:id", do: Campfire.Sessions.transfer(conn, id, conn.params))
  patch("/session/transfers/:id", do: Campfire.Sessions.transfer(conn, id, conn.params))

  post("/users/:user_id/ban", do: Campfire.Admin.call(conn, :ban, user_id))
  delete("/users/:user_id/ban", do: Campfire.Admin.call(conn, :unban, user_id))

  post("/users/:user_id/push_subscriptions/:id/test_notifications",
    do: Campfire.PushSubscriptions.test_notification(conn, id)
  )

  get("/users/:user_id/push_subscriptions", do: Campfire.PushSubscriptions.call(conn))
  post("/users/:user_id/push_subscriptions", do: Campfire.PushSubscriptions.call(conn))
  delete("/users/:user_id/push_subscriptions/:id", do: Campfire.PushSubscriptions.call(conn, id))

  get("/account/users", do: Campfire.AccountPage.index(conn))
  get("/account/users.turbo_stream", do: Campfire.AccountPage.index(conn))
  get("/account/edit", do: Campfire.AccountPage.show(conn))
  get("/account/custom_styles/edit", do: Campfire.SettingsPages.call(conn, :custom_styles))
  get("/account/bots", do: Campfire.BotsPage.show(conn))
  get("/account/bots/new", do: Campfire.SettingsPages.call(conn, :new_bot))
  get("/account/bots/:id/edit", do: Campfire.SettingsPages.call(conn, :edit_bot, id))

  put("/account", do: Campfire.Admin.call(conn, :account, nil))
  patch("/account", do: Campfire.Admin.call(conn, :account, nil))
  post("/account/join_code", do: Campfire.Admin.call(conn, :join_code, nil))
  put("/account/custom_styles", do: Campfire.Admin.call(conn, :custom_styles, nil))
  patch("/account/custom_styles", do: Campfire.Admin.call(conn, :custom_styles, nil))
  put("/account/users/:id", do: Campfire.Admin.call(conn, :role, id))
  patch("/account/users/:id", do: Campfire.Admin.call(conn, :role, id))
  get("/users/:user_id/profile", do: Campfire.ProfilePage.show(conn))
  put("/users/:user_id/profile", do: Campfire.Admin.call(conn, :profile, nil))
  patch("/users/:user_id/profile", do: Campfire.Admin.call(conn, :profile, nil))
  put("/account/bots/:id", do: Campfire.Admin.call(conn, :update_bot, id))
  patch("/account/bots/:id", do: Campfire.Admin.call(conn, :update_bot, id))
  put("/account/bots/:bot_id/key", do: Campfire.Admin.call(conn, :reset_bot_key, bot_id))
  patch("/account/bots/:bot_id/key", do: Campfire.Admin.call(conn, :reset_bot_key, bot_id))
  delete("/account/users/:id", do: Campfire.Admin.call(conn, :deactivate, id))
  delete("/account/bots/:id", do: Campfire.Admin.call(conn, :delete_bot, id))
  post("/account/bots", do: Campfire.Admin.call(conn, :create_bot))
  post("/rooms/opens", do: Campfire.Admin.call(conn, {:create_room, "Rooms::Open"}))
  put("/rooms/opens/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Open"}, id))
  patch("/rooms/opens/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Open"}, id))
  delete("/rooms/opens/:id", do: Campfire.Admin.call(conn, {:delete_room, "Rooms::Open"}, id))
  post("/rooms/closeds", do: Campfire.Admin.call(conn, {:create_room, "Rooms::Closed"}))
  put("/rooms/closeds/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Closed"}, id))
  patch("/rooms/closeds/:id", do: Campfire.Admin.call(conn, {:update_room, "Rooms::Closed"}, id))
  delete("/rooms/closeds/:id", do: Campfire.Admin.call(conn, {:delete_room, "Rooms::Closed"}, id))
  post("/rooms/directs", do: Campfire.Admin.call(conn, {:create_room, "Rooms::Direct"}))
  delete("/rooms/directs/:id", do: Campfire.Admin.call(conn, {:delete_room, "Rooms::Direct"}, id))
  delete("/rooms/:id", do: Campfire.Admin.call(conn, {:delete_room, nil}, id))
  put("/rooms/:id/involvement", do: Campfire.Admin.call(conn, :involvement, id))
  patch("/rooms/:id/involvement", do: Campfire.Admin.call(conn, :involvement, id))

  get("/rails/active_storage/blobs/redirect/:id/*filename",
    do: Campfire.Storage.redirect_blob(conn, id)
  )

  get("/rails/active_storage/representations/redirect/:id/:variation_key/*filename",
    do: Campfire.Storage.representation(conn, id, variation_key)
  )

  get("/rails/active_storage/representations/proxy/:id/:variation_key/*filename",
    do: Campfire.Storage.representation(conn, id, variation_key, true)
  )

  get("/rails/active_storage/representations/:id/:variation_key/*filename",
    do: Campfire.Storage.representation(conn, id, variation_key)
  )

  get("/rails/active_storage/blobs/proxy/:id/*filename", do: Campfire.Storage.proxy(conn, id))
  get("/rails/active_storage/blobs/:id/*filename", do: Campfire.Storage.redirect_blob(conn, id))
  get("/rails/active_storage/disk/:id/*filename", do: Campfire.Storage.disk(conn, id))
  put("/rails/active_storage/disk/:id", do: Campfire.Storage.upload(conn, id))
  post("/rails/active_storage/direct_uploads", do: Campfire.Storage.direct_upload(conn))

  match("/messages/:message_id/boosts", do: Campfire.Boosts.call(conn, message_id))
  match("/messages/:message_id/boosts/:id", do: Campfire.Boosts.call(conn, message_id, id))

  get("/messages/:id/edit", do: Campfire.Messages.call(conn, conn.params["room_id"], id, true))
  match("/messages", do: Campfire.Messages.call(conn, conn.params["room_id"]))
  match("/messages/:id", do: Campfire.Messages.call(conn, conn.params["room_id"], id))
  get("/rooms/:room_id/messages/:id/edit", do: Campfire.Messages.call(conn, room_id, id, true))

  match("/rooms/:room_id/messages", do: Campfire.Messages.call(conn, room_id))
  match("/rooms/:room_id/messages/:id", do: Campfire.Messages.call(conn, room_id, id))

  match(_, do: Campfire.HttpResponse.error(conn, 404))

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
          not Auth.csrf_valid?(conn, conn.params) ->
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
          not Auth.csrf_valid?(conn, conn.params) ->
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
          {conn, data} = Auth.csrf_session(conn)
          token = Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"]))

          body =
            "\n" <> Enum.map_join(messages, &Campfire.MessagesView.render(&1, base(conn), token))

          conn
          |> Auth.set_csrf_session(data)
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
