defmodule Campfire.PushSubscriptions do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Chat, DB, Page, Push, Rails, UserAgent}
  require EEx
  EEx.function_from_file(:defp, :page, "priv/templates/push_subscriptions.html.eex", [:assigns])
  EEx.function_from_file(:defp, :row, "priv/templates/push_subscription.html.eex", [:assigns])

  EEx.function_from_file(:defp, :nav, "priv/templates/push_subscriptions_nav.html.eex", [:assigns])

  def call(conn, id \\ nil) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      conn.method not in ["GET", "HEAD"] && !Auth.csrf_valid?(conn, conn.params) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      true ->
        action(Auth.set_auth_cookie(conn, session), user, id)
    end
  end

  def test_notification(conn, id) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      !Auth.csrf_valid?(conn, conn.params) ->
        Campfire.HttpResponse.error(conn, 422)

      true ->
        subscription =
          DB.one("SELECT * FROM push_subscriptions WHERE id=? AND user_id=?", [
            Chat.integer(id),
            user["id"]
          ])

        if subscription do
          badge =
            DB.one(
              "SELECT count(*) AS count FROM memberships WHERE user_id=? AND unread_at IS NOT NULL",
              [user["id"]]
            )["count"]

          payload = %{
            "title" => "Campfire Test",
            "body" => Chat.uuid(),
            "path" => Auth.base(conn) <> "/users/me/push_subscriptions"
          }

          case Push.deliver(subscription, payload, badge, invalidate: false) do
            result when result in [:ok, :skipped] ->
              conn
              |> Auth.set_auth_cookie(session)
              |> Auth.redirect("/users/me/push_subscriptions")

            _ ->
              Campfire.HttpResponse.error(conn, 500)
          end
        else
          Campfire.HttpResponse.error(conn, 404)
        end
    end
  rescue
    _ -> Campfire.HttpResponse.error(conn, 500)
  end

  defp action(%{method: "GET"} = conn, user, nil) do
    {conn, data} = Auth.csrf_session(conn)

    rows =
      DB.query("SELECT * FROM push_subscriptions WHERE user_id=?", [user["id"]])
      |> Enum.map_join(fn subscription ->
        agent = UserAgent.parse(subscription["user_agent"])
        path = "/users/me/push_subscriptions/#{subscription["id"]}"

        row(
          id: subscription["id"],
          endpoint: Assets.html_escape(subscription["endpoint"] || ""),
          browser: Assets.html_escape(to_string(UserAgent.browser(agent))),
          version: Assets.html_escape(to_string(UserAgent.version(agent))),
          platform: Assets.html_escape(to_string(UserAgent.platform(agent))),
          test_token:
            Rails.csrf_mask(
              Rails.csrf_form(data["_csrf_token"], path <> "/test_notifications", "POST")
            ),
          delete_token: Rails.csrf_mask(Rails.csrf_form(data["_csrf_token"], path, "DELETE"))
        )
      end)

    last = if conn.cookies["last_room"], do: Chat.room(user, conn.cookies["last_room"])

    last =
      last ||
        DB.one(
          "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.created_at LIMIT 1",
          [user["id"]]
        )

    back = if last, do: "/rooms/#{last["id"]}", else: "/"

    {conn, html} =
      Page.render(conn, user, data,
        title: "Push notification subscriptions",
        nav: nav(back: back),
        content: page(rows: rows)
      )

    conn |> put_resp_content_type("text/html") |> send_resp(200, html)
  end

  defp action(%{method: "DELETE"} = conn, user, id) do
    DB.query("DELETE FROM push_subscriptions WHERE id=? AND user_id=?", [
      Chat.integer(id),
      user["id"]
    ])

    Auth.redirect(conn, "/users/me/push_subscriptions")
  end

  defp action(%{method: "POST"} = conn, user, nil) do
    if is_map(conn.params["push_subscription"]) do
      attrs = Map.take(conn.params["push_subscription"], ~w(endpoint p256dh_key auth_key))

      clauses =
        Enum.map_join(attrs, " AND ", fn {k, v} ->
          if is_nil(v), do: k <> " IS NULL", else: k <> "=?"
        end)

      args = attrs |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Enum.map(fn {_, v} -> v end)

      existing =
        DB.one(
          "SELECT * FROM push_subscriptions WHERE user_id=?" <>
            if(clauses == "", do: "", else: " AND " <> clauses) <> " LIMIT 1",
          [user["id"] | args]
        )

      endpoint = if existing, do: existing["endpoint"], else: attrs["endpoint"]

      if Push.valid_endpoint?(endpoint) do
        now = Chat.timestamp()

        if existing do
          DB.query("UPDATE push_subscriptions SET updated_at=? WHERE id=?", [now, existing["id"]])
        else
          DB.query(
            "INSERT INTO push_subscriptions (user_id,endpoint,p256dh_key,auth_key,user_agent,created_at,updated_at) VALUES (?,?,?,?,?,?,?)",
            [
              user["id"],
              endpoint,
              attrs["p256dh_key"],
              attrs["auth_key"],
              List.first(get_req_header(conn, "user-agent")),
              now,
              now
            ]
          )
        end

        conn |> put_resp_header("content-type", "text/html") |> send_resp(200, "")
      else
        conn |> put_resp_header("content-type", "text/html") |> send_resp(422, "")
      end
    else
      send_resp(conn, 400, "")
    end
  end
end
