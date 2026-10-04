defmodule Campfire.Autocomplete do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Chat, DB, Mentions, Rails, Sidebar}
  require EEx
  EEx.function_from_file(:defp, :item, "priv/templates/prompt_item.html.eex", [:assigns])

  def index(conn) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      Chat.present?(conn.params["room_id"]) && !Chat.room(user, conn.params["room_id"]) ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, ~s({"status":404,"error":"Not Found"}))

      true ->
        query =
          if Chat.present?(conn.params["filter"]),
            do: conn.params["filter"],
            else: conn.params["query"]

        {scope, args} =
          if Chat.present?(conn.params["room_id"]),
            do:
              {" AND id IN (SELECT user_id FROM memberships WHERE room_id=?)",
               [Chat.integer(conn.params["room_id"])]},
            else: {"", []}

        {filter, args} =
          if Chat.present?(query),
            do: {" AND name LIKE ?", args ++ ["%#{query}%"]},
            else: {"", args}

        page = max(Chat.integer(conn.params["page"] || "1"), 1)

        users =
          DB.query(
            "SELECT * FROM users WHERE status=0" <>
              scope <> filter <> " ORDER BY LOWER(name) LIMIT 20 OFFSET ?",
            args ++ [(page - 1) * 20]
          )

        conn = Auth.set_auth_cookie(conn, session)

        if conn.params["format"] == "json" ||
             Enum.any?(get_req_header(conn, "accept"), &String.contains?(&1, "application/json")) do
          value =
            Enum.map(users, fn u ->
              %{
                "name" => Assets.html_escape(u["name"]),
                "value" => u["id"],
                "avatar_url" => Auth.base(conn) <> Sidebar.avatar_path(u),
                "sgid" => Rails.attachable_sgid("User", u["id"])
              }
            end)

          count =
            DB.one("SELECT count(*) AS count FROM users WHERE status=0" <> scope <> filter, args)[
              "count"
            ]

          conn = put_resp_header(conn, "x-total-count", to_string(count))

          conn =
            if page == max(div(count + 19, 20), 1) do
              conn
            else
              query =
                Map.put(conn.query_params, "page", to_string(page + 1))
                |> Enum.sort()
                |> URI.encode_query()

              put_resp_header(
                conn,
                "link",
                ~s(<#{Auth.base(conn)}#{conn.request_path}?#{query}>; rel="next")
              )
            end

          conn |> put_resp_content_type("application/json") |> send_resp(200, Rails.json(value))
        else
          body =
            Enum.map_join(users, fn u ->
              item(
                name: Assets.html_escape(u["name"]),
                sgid: Rails.attachable_sgid("User", u["id"]),
                avatar: Mentions.avatar(u, :page)
              )
            end)

          conn |> put_resp_content_type("text/html") |> send_resp(200, body <> "\n")
        end
    end
  end
end
