defmodule Campfire.SessionsTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn, only: [put_req_header: 3]
  alias Campfire.{Auth, DB, Rails, Router}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  setup do
    Campfire.RateLimiter.clear()
    DB.restore_fixture(@fixture)
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T16:00:00Z")
    on_exit(fn -> System.delete_env("CAMPFIRE_CLOCK") end)
    :ok
  end

  defp browser do
    conn(:get, "/session/new") |> Router.call(Router.init([]))
  end

  defp csrf_post(method, path, params) do
    conn(method, path, params)
    |> put_req_header("sec-fetch-site", "same-origin")
    |> Router.call(Router.init([]))
  end

  defp forgery_check(headers, scheme \\ :http) do
    conn = %{conn(:post, "/session") | scheme: scheme, host: "campfire.test", port: 443}

    conn =
      Enum.reduce(headers, conn, fn {name, value}, conn -> put_req_header(conn, name, value) end)

    Auth.csrf_valid?(conn, %{})
  end

  test "login renders original frontend without a forgery token or session" do
    page = browser()
    assert page.status == 200
    assert page.resp_body =~ "<title>Sign in</title>"
    assert page.resp_body =~ "application-a54c74a7.js"
    assert page.resp_body =~ ~s(<meta name="csrf-token" content="" />)
    refute page.resp_body =~ ~s(name="authenticity_token" value=)
    refute page.resp_cookies["_campfire_session"]
    assert length(Regex.scan(~r/lifebuoy-/, page.resp_body)) == 1

    assert csrf_post(:post, "/session", %{
             "email_address" => "david@37signals.com",
             "password" => "wrong"
           }).status == 401
  end

  test "valid credentials start a Rails-readable session; Sec-Fetch-Site rejects forgery" do
    assert csrf_post(:post, "/session", %{
             "email_address" => "david@37signals.com",
             "password" => "secret123456"
           }).status == 302

    session = DB.one("SELECT * FROM sessions ORDER BY id DESC LIMIT 1")
    assert session["user_id"] == 127_326_141
    assert String.length(session["token"]) == 24

    forged =
      conn(:post, "/session", %{
        "email_address" => "david@37signals.com",
        "password" => "secret123456"
      })
      |> put_req_header("sec-fetch-site", "cross-site")
      |> Router.call(Router.init([]))

    assert forged.status == 422
  end

  test "forgery protection follows Sec-Fetch-Site and Origin" do
    for site <- ["same-origin", "same-site"] do
      assert forgery_check([{"sec-fetch-site", site}])
      assert forgery_check([{"sec-fetch-site", site}], :https)
    end

    for site <- ["cross-site", "none", "bogus"] do
      refute forgery_check([{"sec-fetch-site", site}])
      refute forgery_check([{"sec-fetch-site", site}], :https)
    end

    # Browsers send Sec-Fetch-Site only to secure origins.
    assert forgery_check([])
    refute forgery_check([], :https)

    assert forgery_check(
             [{"origin", "https://campfire.test"}, {"sec-fetch-site", "same-origin"}],
             :https
           )

    refute forgery_check(
             [{"origin", "https://evil.test"}, {"sec-fetch-site", "same-origin"}],
             :https
           )

    refute forgery_check([{"origin", "null"}, {"sec-fetch-site", "same-origin"}], :https)
  end

  test "the session cookie is written only when its data changes" do
    page = browser()
    refute page.resp_cookies["_campfire_session"]

    data = %{
      "session_id" => "abc",
      "flash" => %{"discard" => [], "flashes" => %{"notice" => "Hi"}}
    }

    cookie = URI.encode(Rails.encrypt_cookie("_campfire_session", data), &URI.char_unreserved?/1)
    conn = conn(:get, "/") |> put_req_cookie("_campfire_session", cookie)

    unchanged = Auth.set_csrf_session(conn, data)
    refute unchanged.resp_cookies["_campfire_session"]

    changed = Auth.set_csrf_session(conn, Map.delete(data, "flash"))
    written = changed.resp_cookies["_campfire_session"][:value]

    assert Rails.decrypt_cookie("_campfire_session", URI.decode(written)) == %{
             "session_id" => "abc"
           }
  end

  test "return-to is removed once and the newly signed authentication cookie verifies" do
    c = conn(:get, "/rooms/486777696?before=123") |> Auth.request_authentication()
    cookie = c.resp_cookies["_campfire_session"][:value]

    response =
      conn(:post, "/session", %{
        "email_address" => "david@37signals.com",
        "password" => "secret123456"
      })
      |> put_req_header("sec-fetch-site", "same-origin")
      |> put_req_cookie("_campfire_session", cookie)
      |> Router.call(Router.init([]))

    assert Plug.Conn.get_resp_header(response, "location") == [
             "http://www.example.com/rooms/486777696?before=123"
           ]

    assert Rails.verify_cookie(
             "session_token",
             URI.decode(response.resp_cookies["session_token"][:value])
           )

    refute Rails.decrypt_cookie(
             "_campfire_session",
             URI.decode(response.resp_cookies["_campfire_session"][:value])
           )["return_to_after_authenticating"]
  end

  test "session activity refresh is strictly older than one hour" do
    user = DB.one("SELECT * FROM users WHERE id=127326141")
    c = conn(:get, "/") |> Auth.start_session(user)
    raw = c.resp_cookies["session_token"][:value]
    session = DB.one("SELECT * FROM sessions ORDER BY id DESC LIMIT 1")

    DB.query("UPDATE sessions SET last_active_at=? WHERE id=?", [
      "2026-03-02 15:00:00",
      session["id"]
    ])

    {_, _, same} = conn(:get, "/") |> put_req_cookie("session_token", raw) |> Auth.session_user()
    assert same["last_active_at"] == "2026-03-02 15:00:00"

    DB.query("UPDATE sessions SET last_active_at=? WHERE id=?", [
      "2026-03-02 14:59:59",
      session["id"]
    ])

    {_, _, updated} =
      conn(:get, "/") |> put_req_cookie("session_token", raw) |> Auth.session_user()

    assert updated["last_active_at"] == "2026-03-02 16:00:00"
  end

  test "session_token is re-signed only when the session starts or its activity refreshes" do
    user = DB.one("SELECT * FROM users WHERE id=127326141")
    raw = (conn(:get, "/") |> Auth.start_session(user)).resp_cookies["session_token"][:value]
    session = DB.one("SELECT * FROM sessions ORDER BY id DESC LIMIT 1")

    resign = fn ->
      {conn, ^user, session} =
        conn(:get, "/") |> put_req_cookie("session_token", raw) |> Auth.session_user()

      Auth.set_auth_cookie(conn, session).resp_cookies["session_token"]
    end

    refute resign.()

    DB.query("UPDATE sessions SET last_active_at=? WHERE id=?", [
      "2026-03-02 14:59:59",
      session["id"]
    ])

    assert %{value: value} = resign.()
    assert Rails.verify_cookie("session_token", URI.decode(value)) == session["token"]
  end

  test "a room page renders the same bytes and ETag twice and revalidates with 304" do
    user = DB.one("SELECT * FROM users WHERE id=127326141")
    raw = (conn(:get, "/") |> Auth.start_session(user)).resp_cookies["session_token"][:value]

    get = fn headers ->
      Enum.reduce(headers, conn(:get, "/rooms/486777696"), fn {name, value}, conn ->
        put_req_header(conn, name, value)
      end)
      |> put_req_cookie("session_token", raw)
      |> put_req_header("accept-encoding", "gzip")
      |> Router.call(Router.init([]))
    end

    first = get.([])
    second = get.([])
    assert first.status == 200
    assert :zlib.gunzip(IO.iodata_to_binary(first.resp_body)) =~ "message__body"

    assert :zlib.gunzip(IO.iodata_to_binary(first.resp_body)) ==
             :zlib.gunzip(IO.iodata_to_binary(second.resp_body))

    [etag] = Plug.Conn.get_resp_header(first, "etag")
    assert Plug.Conn.get_resp_header(second, "etag") == [etag]
    assert get.([{"if-none-match", etag}]).status == 304
  end

  test "login rate limit rejects the eleventh same-origin attempt" do
    for _ <- 1..10,
        do:
          assert(
            csrf_post(:post, "/session", %{
              "email_address" => "david@37signals.com",
              "password" => "bad"
            }).status == 401
          )

    assert csrf_post(:post, "/session", %{
             "email_address" => "david@37signals.com",
             "password" => "bad"
           }).status == 429
  end

  test "transfer requires purpose, unexpired signature and active user" do
    good = Rails.signed_id("User", 127_326_141, "transfer", "2026-03-02T20:00:00Z")
    assert csrf_post(:put, "/session/transfers/" <> good, %{}).status == 302
    wrong = Rails.signed_id("User", 127_326_141, "avatar")
    assert csrf_post(:put, "/session/transfers/" <> wrong, %{}).status == 400
    expired = Rails.signed_id("User", 127_326_141, "transfer", "2026-03-02T15:59:59Z")
    assert csrf_post(:put, "/session/transfers/" <> expired, %{}).status == 400
    DB.query("UPDATE users SET status=1 WHERE id=127326141")
    assert csrf_post(:put, "/session/transfers/" <> good, %{}).status == 400
  end
end
