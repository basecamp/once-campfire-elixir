defmodule Campfire.Auth do
  alias Campfire.{DB, Rails, Chat}
  import Plug.Conn

  @session_columns ~w(id created_at ip_address last_active_at token updated_at user_agent user_id)
  @session_keys Enum.map(@session_columns, &("session." <> &1))
  # The session and its user in one query; session columns are prefixed to keep them apart.
  @session_user_sql "SELECT u.*, " <>
                      Enum.map_join(@session_columns, ", ", &~s(s."#{&1}" AS "session.#{&1}")) <>
                      " FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token=?"

  def session_lookup(conn) do
    conn = fetch_cookies(conn)

    with raw when is_binary(raw) <- conn.cookies["session_token"],
         token when is_binary(token) <- session_token(raw),
         row when is_map(row) <- DB.one(@session_user_sql, [token]) do
      {session, user} = Map.split(row, @session_keys)
      {conn, user, Map.new(session, fn {"session." <> key, value} -> {key, value} end)}
    else
      _ -> {conn, nil, nil}
    end
  end

  # A verified session_token cookie is kept (its signature check is deterministic), and only its
  # expiry is compared with the clock on later requests. Unverifiable cookies are not kept.
  defp session_token(raw) do
    now = Campfire.Clock.now()

    verified =
      Campfire.FragmentCache.memo({:session_cookie, raw}, 64 + byte_size(raw), fn ->
        Rails.verify_cookie_expiry("session_token", URI.decode(raw), now)
      end)

    case verified do
      {token, nil} -> token
      {token, expires} -> if DateTime.compare(expires, now) == :gt, do: token
      nil -> nil
    end
  end

  # Resolved once per request; later calls reuse the guard's lookup.
  def session_user(%{private: %{campfire_session_user: {user, session}}} = conn),
    do: {conn, user, session}

  def session_user(conn) do
    {conn, user, session, current} =
      case session_lookup(conn) do
        {conn, nil, nil} ->
          {conn, nil, nil, false}

        {conn, user, session} ->
          resumed = resume_session(conn, session)
          {conn, user, resumed, resumed == session}
      end

    conn =
      conn
      |> put_private(:campfire_session_user, {user, session})
      |> put_private(:campfire_session_cookie_current, current)

    {conn, user, session}
  end

  defp forget_session_user(conn),
    do: %{
      conn
      | private:
          Map.drop(conn.private, [:campfire_session_user, :campfire_session_cookie_current])
    }

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

    conn |> forget_session_user() |> set_auth_cookie(session)
  end

  # The signed session_token cookie is re-issued (with its 20-year expiry) when a session starts
  # and when its hourly activity refresh runs, not on every request: the client already holds
  # a valid cookie for this session otherwise.
  def set_auth_cookie(
        %{
          private: %{
            campfire_session_user: {_, %{"id" => id}},
            campfire_session_cookie_current: true
          }
        } = conn,
        %{"id" => id}
      ),
      do: conn

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

  # The `_campfire_session` cookie's data, decrypted at most once per request (cached by raw
  # value in the process dictionary, which Campfire.HttpResponse clears per request). Forgery
  # protection no longer needs a session, so a request without the cookie gets empty data and
  # none is written unless something is stored in it.
  def csrf_session(conn) do
    conn = fetch_cookies(conn)
    {conn, decrypt_session(conn.cookies["_campfire_session"])}
  end

  defp decrypt_session(raw) when is_binary(raw) do
    case Process.get(:campfire_session) do
      {^raw, data} ->
        data

      _ ->
        data =
          case Rails.decrypt_cookie("_campfire_session", URI.decode(raw)) do
            data when is_map(data) -> data
            _ -> %{}
          end

        Process.put(:campfire_session, {raw, data})
        data
    end
  end

  defp decrypt_session(_), do: %{}

  # Writes the session cookie only when its data differs from what the client already holds
  # (or what this response already set).
  def set_csrf_session(conn, data) do
    current =
      case conn.private do
        %{campfire_session_written: written} -> written
        _ -> elem(csrf_session(conn), 1)
      end

    if Map.delete(data, "session_id") == Map.delete(current, "session_id") do
      conn
    else
      data =
        Map.put_new_lazy(data, "session_id", fn ->
          current["session_id"] || Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
        end)

      conn
      |> put_private(:campfire_session_written, data)
      |> put_resp_cookie(
        "_campfire_session",
        URI.encode(Rails.encrypt_cookie("_campfire_session", data), &URI.char_unreserved?/1),
        http_only: true,
        same_site: "Lax",
        max_age: DateTime.diff(permanent_expiry(), Campfire.Clock.now())
      )
    end
  end

  # Forgery protection by `Sec-Fetch-Site` instead of tokens, as in Rails main's
  # `protect_from_forgery using: :header_only` and the Rust port. Browsers send the header on
  # every request to a secure origin; without it (plain HTTP, or an old browser) a write is
  # allowed only over plain HTTP, where the SameSite=Lax session cookie and the Origin check
  # protect it. Callers apply this to non-GET/HEAD requests.
  def csrf_valid?(conn, _params) do
    origin = List.first(get_req_header(conn, "origin"))

    cond do
      origin == "null" ->
        false

      not is_nil(origin) and origin != base(conn) ->
        false

      true ->
        case List.first(get_req_header(conn, "sec-fetch-site")) do
          site when site in ["same-origin", "same-site"] -> true
          nil -> conn.scheme != :https
          _ -> false
        end
    end
  end

  def request_authentication(conn) do
    {conn, data} = csrf_session(conn)

    conn
    |> set_csrf_session(
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
    {conn, data} = csrf_session(conn)
    destination = data["return_to_after_authenticating"] || base(conn) <> "/"

    conn
    |> set_csrf_session(Map.delete(data, "return_to_after_authenticating"))
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

    conn
    |> forget_session_user()
    |> delete_resp_cookie("session_token")
    |> delete_resp_cookie("_campfire_session")
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
