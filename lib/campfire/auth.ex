defmodule Campfire.Auth do
  alias Campfire.{Chat, DB, Rails}
  import Plug.Conn

  def session_lookup(conn) do
    conn = fetch_cookies(conn)

    with raw when is_binary(raw) <- conn.cookies["session_token"],
         token when is_binary(token) <- Rails.verify_cookie("session_token", URI.decode(raw)),
         session when is_map(session) <- DB.one("SELECT * FROM sessions WHERE token=?", [token]),
         user when is_map(user) <- DB.one("SELECT * FROM users WHERE id=?", [session["user_id"]]) do
      {conn, user, session}
    else
      _ -> {conn, nil, nil}
    end
  end

  def session_user(%{assigns: %{response_cache_auth: {user, session}}} = conn),
    do: {conn, user, session}

  def session_user(conn) do
    case session_lookup(conn) do
      {conn, nil, nil} -> {conn, nil, nil}
      {conn, user, session} -> {conn, user, resume_session(conn, session)}
    end
  end

  def start_session(conn, user) do
    now = Chat.timestamp()
    token = random_token(24)

    [session] =
      DB.query(
        "INSERT INTO sessions (user_id,token,user_agent,ip_address,last_active_at,created_at,updated_at) VALUES (?,?,?,?,?,?,?) RETURNING *",
        [
          user["id"],
          token,
          List.first(get_req_header(conn, "user-agent")),
          Campfire.RemoteIP.address(conn),
          now,
          now,
          now
        ]
      )

    set_auth_cookie(conn, session)
  end

  def set_auth_cookie(conn, session) do
    expires = permanent_expiry() |> DateTime.to_iso8601()
    value = Rails.sign_cookie("session_token", session["token"], expires)

    put_resp_cookie(conn, "session_token", URI.encode(value, &URI.char_unreserved?/1),
      http_only: true,
      same_site: "Lax",
      max_age: DateTime.diff(permanent_expiry(), Campfire.Clock.now())
    )
  end

  def bot_or_session(conn, key) do
    case session_user(conn) do
      {conn, nil, _} ->
        {conn, Chat.bot(if(is_binary(key), do: String.trim(key), else: key)), :bot}

      {conn, user, session} ->
        {set_auth_cookie(conn, session), user, :session}
    end
  end

  def banned?(conn) do
    conn.method not in ["GET", "HEAD"] and
      DB.one("SELECT id FROM bans WHERE ip_address=? LIMIT 1", [
        Campfire.RemoteIP.address(conn)
      ]) != nil
  end

  def browser_session(%{assigns: %{response_cache_session: data}} = conn), do: {conn, data}

  def browser_session(conn) do
    conn = fetch_cookies(conn)

    data =
      case conn.cookies["_campfire_session"] do
        raw when is_binary(raw) -> Rails.decrypt_cookie("_campfire_session", URI.decode(raw))
        _ -> nil
      end

    if is_map(data),
      do: {conn, data},
      else:
        {conn,
         %{
           "session_id" => Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
         }}
  end

  def set_browser_session(conn, data),
    do:
      put_resp_cookie(
        conn,
        "_campfire_session",
        URI.encode(Rails.encrypt_cookie("_campfire_session", data), &URI.char_unreserved?/1),
        http_only: true,
        same_site: "Lax",
        max_age: DateTime.diff(permanent_expiry(), Campfire.Clock.now())
      )

  def request_allowed?(conn) do
    if conn.method in ["GET", "HEAD"] do
      true
    else
      origins = get_req_header(conn, "origin")
      origin_ok = origins == [] or origins == [base(conn)]

      origin_ok &&
        case get_req_header(conn, "sec-fetch-site") do
          [site] when site in ["same-origin", "same-site"] ->
            true

          [] ->
            conn.scheme == :http &&
              String.downcase(System.get_env("FORCE_SSL", "")) not in ["1", "true"]

          _ ->
            false
        end
    end
  end

  def request_authentication(conn) do
    {conn, data} = browser_session(conn)

    conn
    |> set_browser_session(
      Map.put(
        data,
        "return_to_after_authenticating",
        base(conn) <>
          conn.request_path <> if(conn.query_string == "", do: "", else: "?" <> conn.query_string)
      )
    )
    |> redirect("/session/new")
  end

  def post_authenticating(conn) do
    {conn, data} = browser_session(conn)
    destination = data["return_to_after_authenticating"] || base(conn) <> "/"

    conn
    |> set_browser_session(Map.delete(data, "return_to_after_authenticating"))
    |> redirect(destination)
  end

  def terminate_session(conn, session, endpoint \\ nil) do
    if endpoint,
      do:
        DB.query("DELETE FROM push_subscriptions WHERE user_id=? AND endpoint=?", [
          session["user_id"],
          endpoint
        ])

    DB.query("DELETE FROM sessions WHERE id=?", [session["id"]])
    Campfire.Cable.disconnect(session["user_id"], true)
    conn |> delete_resp_cookie("session_token") |> delete_resp_cookie("_campfire_session")
  end

  def redirect(conn, destination) do
    location =
      if String.starts_with?(destination, "/"), do: base(conn) <> destination, else: destination

    conn
    |> put_resp_content_type("text/html")
    |> put_resp_header("location", location)
    |> send_resp(302, "")
  end

  def resume_session(conn, session) do
    cutoff =
      Campfire.Clock.now()
      |> DateTime.add(-3600)
      |> DateTime.to_naive()
      |> NaiveDateTime.to_string()
      |> String.replace("T", " ")

    if session["last_active_at"] < cutoff do
      now = Chat.timestamp()

      DB.one(
        "UPDATE sessions SET user_agent=?,ip_address=?,last_active_at=?,updated_at=? WHERE id=? RETURNING *",
        [
          List.first(get_req_header(conn, "user-agent")),
          Campfire.RemoteIP.address(conn),
          now,
          now,
          session["id"]
        ]
      )
    else
      session
    end
  end

  def permanent_expiry do
    now = Campfire.Clock.now()
    year = now.year + 20
    day = min(now.day, Calendar.ISO.days_in_month(year, now.month))
    %{now | year: year, day: day}
  end

  def random_token(length) do
    Campfire.Random.token(length, "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
  end

  def base(conn),
    do:
      "#{conn.scheme}://#{conn.host}" <>
        if(conn.port == if(conn.scheme == :https, do: 443, else: 80),
          do: "",
          else: ":#{conn.port}"
        )
end
