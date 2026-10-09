defmodule Campfire.BrowserGuard do
  import Plug.Conn
  alias Campfire.{Assets, Auth, Page, Platform}
  require EEx

  EEx.function_from_file(:defp, :incompatible, "priv/templates/incompatible_browser.html.eex", [
    :_assigns
  ])

  def init(options), do: options

  def call(conn, _) do
    cond do
      exempt?(conn) ->
        conn

      Auth.banned?(conn) ->
        conn |> put_resp_header("content-type", "text/html") |> send_resp(429, "") |> halt()

      true ->
        show_if_authorized(conn)
    end
  rescue
    error in [KeyError, ArgumentError] ->
      _ = error

      conn
      |> Campfire.HttpResponse.exception(500, Campfire.Assets.read("public/500.html"))
      |> halt()
  end

  defp exempt?(conn),
    do:
      conn.request_path in ["/up", "/cable"] ||
        String.starts_with?(conn.request_path, "/rails/active_storage/")

  defp public?(conn) do
    conn.request_path in [
      "/session/new",
      "/first_run",
      "/webmanifest.json",
      "/webmanifest",
      "/service-worker.js",
      "/service-worker"
    ] || (conn.request_path == "/session" && conn.method == "POST") ||
      String.starts_with?(conn.request_path, ["/join/", "/session/transfers/", "/qr_code/"]) ||
      (conn.method == "GET" &&
         conn.request_path == "/account/logo")
  end

  defp show_if_authorized(conn) do
    {conn, user, session} =
      if public?(conn), do: {conn, nil, nil}, else: Campfire.ResponseCache.authenticate(conn)

    bot_key = conn.path_params["bot_key"]

    query_bot =
      !public?(conn) && !user && !bot_key &&
        is_binary(conn.params["bot_key"]) &&
        Campfire.Chat.bot(String.trim(conn.params["bot_key"]))

    {conn, user, method} =
      if bot_key, do: Auth.bot_or_session(conn, bot_key), else: {conn, user, :session}

    cond do
      query_bot ->
        conn |> put_resp_header("content-type", "text/html") |> send_resp(403, "") |> halt()

      !public?(conn) && !user ->
        conn

      user && user["role"] == 2 && !bot_key ->
        conn

      conn.method not in ["GET", "HEAD"] && method != :bot && !Auth.request_allowed?(conn) ->
        conn

      conn.method not in ["GET", "HEAD"] && Auth.banned?(conn) ->
        conn

      !Platform.blocked?(List.first(get_req_header(conn, "user-agent"))) ->
        conn

      true ->
        # This page is sent from here, so its rows come from the database, as they did.
        {conn, user, session} = Campfire.ResponseCache.reauthenticate(conn, user, session)
        conn = if session, do: Auth.set_auth_cookie(conn, session), else: conn
        {conn, data} = Auth.browser_session(conn)
        raw = List.first(get_req_header(conn, "user-agent")) || ""
        lower = String.downcase(raw)

        title =
          if String.contains?(lower, "facebookexternalhit") &&
               String.contains?(lower, "twitterbot"), do: "Campfire", else: "Unsupported browser"

        {conn, html} = Page.render(conn, user, data, title: title, content: incompatible([]))
        conn |> put_resp_content_type("text/html") |> send_resp(200, html) |> halt()
    end
  end
end
