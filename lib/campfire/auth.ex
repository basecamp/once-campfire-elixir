defmodule Campfire.Auth do
  alias Campfire.{Chat, DB, Rails}
  import Plug.Conn

  @memo :campfire_cookie_memo

  @doc "The table Campfire.CookieMemo owns."
  def cookie_memo, do: @memo

  def session_lookup(conn) do
    do_session_lookup(conn)
  end

  defp do_session_lookup(conn) do
    conn = fetch_cookies(conn)
    version = Campfire.ResponseCache.current_version()

    case conn.cookies["session_token"] do
      raw when is_binary(raw) ->
        case Campfire.SessionStore.fetch(version, {:session_cookie, raw}, fn ->
               verify_session(raw, version)
             end) do
          {user, session} -> {conn, user, session}
          nil -> {conn, nil, nil}
        end

      _ ->
        {conn, nil, nil}
    end
  end

  # Verifying the signed cookie costs more than the two reads behind it, and both depend only on
  # the cookie and the database version: a revoked session commits a new version, which makes the
  # memo unreachable.
  defp verify_session(raw, version) do
    with token when is_binary(token) <-
           Rails.verify_cookie("session_token", Campfire.CookieCodec.decode(raw)),
         {user, session} when is_map(user) <-
           Campfire.SessionStore.fetch(version, {:session, token}, fn ->
             session_records(token)
           end) do
      {user, session}
    else
      _ -> nil
    end
  end

  defp session_records(token) do
    with session when is_map(session) <- DB.one("SELECT * FROM sessions WHERE token=?", [token]),
         user when is_map(user) <- DB.one("SELECT * FROM users WHERE id=?", [session["user_id"]]) do
      {user, session}
    else
      _ -> nil
    end
  end

  def session_user(%{assigns: %{response_cache_auth: {user, session}}} = conn),
    do: {conn, user, session}

  def session_user(%{assigns: %{auth_session: {user, session}}} = conn),
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

  def set_auth_cookie(conn, session, mode \\ :plug) do
    {expires, _max_age} = permanent_window()
    value = signed_session_token(session["token"], expires)
    put_permanent_cookie(conn, "session_token", value, mode)
  end

  # Calendar arithmetic and two clock reads per reissued cookie cost more than encoding the cookie
  # itself. Both values change once a second, so the connection process keeps the pair.
  # Bandit serves each request in a fresh process, so a memory of the last value has to live in
  # ETS: a process dictionary loses it on every request. Keys carry the second, so entries are
  # valid for exactly the window they describe and the table stays bounded.
  defp permanent_window do
    now = Campfire.Clock.now()
    key = {:window, DateTime.to_unix(now)}

    case memo_get(key) do
      nil ->
        :ok
        expiry = permanent_expiry_at(now)
        value = {DateTime.to_iso8601(expiry), DateTime.diff(expiry, now)}
        memo_put(key, value)
        value

      value ->
        value
    end
  end

  defp memo_get(key) do
    case :ets.lookup(@memo, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp memo_put(key, value) do
    # One live entry per family: the table then holds the current second and one cookie per session
    # instead of growing for as long as the node runs.
    case key do
      {:window, _second} -> :ets.match_delete(@memo, {:window, :_})
      {:header, name, _max_age} -> :ets.match_delete(@memo, {:header, name, :_})
      {:auth_cookie, token, _expires} -> :ets.match_delete(@memo, {:auth_cookie, token, :_})
      _ -> :ok
    end

    :ets.insert(@memo, {key, value})
    :ok
  rescue
    ArgumentError -> :ok
  end

  defp permanent_expiry_at(now) do
    year = now.year + 20
    day = min(now.day, Calendar.ISO.days_in_month(year, now.month))
    %{now | year: year, day: day}
  end

  # Plug stores response cookies in a map and re-encodes them inside send_resp; on a cache hit that
  # merge costs more than the rest of the request. Encoding once and prepending the header produces
  # the same bytes, because it is the same encoder with the same options.
  # :plug keeps resp_cookies populated, which callers and tests read. :header skips the map and the
  # merge Plug performs inside send_resp, and is only used where the bytes are already sent through
  # the response cache.
  @doc """
  Reissues the cookies a cached response carried, as one memoized bundle.

  Rails reissues the permanent cookies on every response, and a cache hit used to rebuild each one
  from its parts: three memo lookups, three encodes and three header prepends per hit. The bundle
  depends only on the session, the browser session, the last room and the current second (the expiry
  lives in the signed value), so it is computed once and replayed.
  """
  def reissue(conn, session, data, last_room, names) do
    {_expires, max_age} = permanent_window()

    key =
      {:reissued, session["token"], data["session_id"], data["flash"], last_room,
       Enum.sort(names)}

    {headers, cookies, cookie_names} =
      case memo_get({key, max_age}) do
        nil ->
          built =
            conn
            |> Map.merge(%{resp_headers: [], resp_cookies: %{}})
            |> then(fn c ->
              if "session_token" in names, do: set_auth_cookie(c, session, :header), else: c
            end)
            |> then(fn c ->
              if "_campfire_session" in names, do: set_browser_session(c, data, :header), else: c
            end)
            |> then(fn c ->
              if "last_room" in names, do: set_last_room_cookie(c, last_room, :header), else: c
            end)

          bundle = {built.resp_headers, built.resp_cookies}
          # one bundle per session and second, not one per second that ever happened
          :ets.match_delete(@memo, {key, :_})
          memo_put({key, max_age}, bundle)
          {headers, cookies} = bundle
          {headers, cookies, Map.keys(cookies)}

        {headers, cookies} ->
          {headers, cookies, Map.keys(cookies)}
      end

    %{
      conn
      | resp_headers: headers ++ conn.resp_headers,
        resp_cookies: Map.merge(conn.resp_cookies, cookies),
        private:
          Map.put(
            conn.private,
            :resp_cookie_names,
            cookie_names ++ List.wrap(conn.private[:resp_cookie_names])
          )
    }
  end

  defp put_permanent_cookie(conn, name, value, :plug) do
    {_expires, max_age} = permanent_window()

    put_resp_cookie(conn, name, value,
      http_only: true,
      same_site: "Lax",
      max_age: max_age
    )
  end

  defp put_permanent_cookie(conn, name, value, :header) do
    {_expires, max_age} = permanent_window()

    header =
      case memo_get({:header, name, max_age}) do
        cached when is_binary(cached) ->
          cached

        _ ->
          cached =
            Plug.Conn.Cookies.encode(name, %{
              value: value,
              path: "/",
              http_only: true,
              same_site: "Lax",
              max_age: max_age
            })

          memo_put({:header, name, max_age}, cached)
          cached
      end

    cookie = %{value: value, path: "/", http_only: true, same_site: "Lax", max_age: max_age}

    %{
      conn
      | private:
          Map.put(conn.private, :resp_cookie_names, [
            name | List.wrap(conn.private[:resp_cookie_names])
          ]),
        resp_cookies: Map.put(conn.resp_cookies, name, cookie),
        resp_headers: [{"set-cookie", header} | conn.resp_headers]
    }
  end

  defp signed_session_token(token, expires) do
    case memo_get({:auth_cookie, token, expires}) do
      nil ->
        cached = Campfire.CookieCodec.encode(Rails.sign_cookie("session_token", token, expires))
        memo_put({:auth_cookie, token, expires}, cached)
        cached

      cached ->
        cached
    end
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

  def browser_session(conn, epoch \\ nil) do
    conn = fetch_cookies(conn)

    data =
      case conn.cookies["_campfire_session"] do
        raw when is_binary(raw) ->
          decrypt_browser_session(raw, epoch)

        _ ->
          nil
      end

    if is_map(data),
      do: {conn, data},
      else:
        {conn,
         %{
           "session_id" => Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
         }}
  end

  defp decrypt_browser_session(raw, nil),
    do: Rails.decrypt_cookie("_campfire_session", Campfire.CookieCodec.decode(raw))

  defp decrypt_browser_session(raw, epoch) do
    Campfire.SessionStore.fetch(epoch, {:browser_session, raw}, fn ->
      Rails.decrypt_cookie("_campfire_session", Campfire.CookieCodec.decode(raw))
    end)
  end

  def set_browser_session(conn, data, mode \\ :plug) do
    put_permanent_cookie(conn, "_campfire_session", encrypted_browser_session(data), mode)
  end

  def set_last_room_cookie(conn, id, mode \\ :header),
    do: put_permanent_cookie(conn, "last_room", id, mode)

  defp encrypted_browser_session(data) do
    case memo_get({:browser_cookie, data}) do
      nil ->
        cached = Campfire.CookieCodec.encode(Rails.encrypt_cookie("_campfire_session", data))
        memo_put({:browser_cookie, data}, cached)
        cached

      cached ->
        cached
    end
  end

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
              String.downcase(Campfire.Env.get("FORCE_SSL", "")) not in ["1", "true"]

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
