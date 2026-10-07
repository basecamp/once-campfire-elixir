defmodule Campfire.SessionsTest do
  use ExUnit.Case, async: false
  import Plug.Test
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
    page = browser()
    cookie = page.resp_cookies["_campfire_session"][:value]
    data = Rails.decrypt_cookie("_campfire_session", URI.decode(cookie))
    token = Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"]))

    conn(method, path, Map.put(params, "authenticity_token", token))
    |> put_req_cookie("_campfire_session", cookie)
    |> Router.call(Router.init([]))
  end

  test "login renders original frontend and reusable CSRF session" do
    page = browser()
    assert page.status == 200
    assert page.resp_body =~ "<title>Sign in</title>"
    assert page.resp_body =~ "application-a54c74a7.js"
    assert page.resp_cookies["_campfire_session"][:http_only]
    assert length(Regex.scan(~r/lifebuoy-/, page.resp_body)) == 1

    assert csrf_post(:post, "/session", %{
             "email_address" => "david@37signals.com",
             "password" => "wrong"
           }).status == 401
  end

  test "valid credentials start a Rails-readable session; CSRF rejects forgery" do
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
      |> Router.call(Router.init([]))

    assert forged.status == 422
  end

  test "return-to is removed once and the newly signed authentication cookie verifies" do
    c = conn(:get, "/rooms/486777696?before=123") |> Auth.request_authentication()
    cookie = c.resp_cookies["_campfire_session"][:value]
    data = Rails.decrypt_cookie("_campfire_session", URI.decode(cookie))
    token = Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"]))

    response =
      conn(:post, "/session", %{
        "email_address" => "david@37signals.com",
        "password" => "secret123456",
        "authenticity_token" => token
      })
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

  test "login rate limit rejects the eleventh valid-CSRF attempt" do
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

  test "transfer GET renders one complete auto-submit form without signing in" do
    before = DB.one("SELECT COUNT(*) AS n FROM sessions")["n"]
    page = conn(:get, "/session/transfers/example") |> Router.call(Router.init([]))
    assert page.status == 200

    assert length(Regex.scan(~r/<form\b/, page.resp_body)) ==
             length(Regex.scan(~r/<\/form>/, page.resp_body))

    assert length(
             Regex.scan(
               ~r/<form\b[^>]*data-controller="auto-submit"[^>]*>(?:\s*<input\b[^>]*>)*\s*<\/form>/,
               page.resp_body
             )
           ) == 1

    assert page.resp_body =~
             ~r/<form[^>]*data-controller="auto-submit"[^>]*action="\/session\/transfers\/example"/

    assert page.resp_body =~ ~r/name="_method" value="put"[^>]*>.*?<\/form>/s
    refute Map.has_key?(page.resp_cookies, "session_token")
    assert DB.one("SELECT COUNT(*) AS n FROM sessions")["n"] == before
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
