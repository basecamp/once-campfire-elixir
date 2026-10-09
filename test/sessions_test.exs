defmodule Campfire.SessionsTest do
  use ExUnit.Case, async: false
  import Plug.Test
  alias Campfire.{Auth, DB, Rails, Router}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  setup do
    Campfire.RateLimiter.clear()
    DB.restore_fixture(@fixture)
    Campfire.Clock.set("2026-03-02T16:00:00Z")
    on_exit(fn -> Campfire.Clock.set(nil) end)
    :ok
  end

  defp browser do
    conn(:get, "/session/new") |> Router.call(Router.init([]))
  end

  defp browser_write(method, path, params) do
    page = browser()
    cookie = page.resp_cookies["_campfire_session"][:value]

    conn(method, path, params)
    |> put_req_cookie("_campfire_session", cookie)
    |> Router.call(Router.init([]))
  end

  test "login renders token-free frontend and a Rails-readable browser session" do
    page = browser()
    assert page.status == 200
    refute page.resp_body =~ ~s(<meta name="csrf-token")
    refute page.resp_body =~ ~s(name="authenticity_token")

    data =
      Rails.decrypt_cookie(
        "_campfire_session",
        URI.decode(page.resp_cookies["_campfire_session"][:value])
      )

    refute Map.has_key?(data, "_csrf_token")
    assert page.resp_body =~ "<title>Sign in</title>"
    assert page.resp_body =~ "application-a54c74a7.js"
    assert page.resp_cookies["_campfire_session"][:http_only]
    assert length(Regex.scan(~r/lifebuoy-/, page.resp_body)) == 1

    assert browser_write(:post, "/session", %{
             "email_address" => "david@37signals.com",
             "password" => "wrong"
           }).status == 401
  end

  test "valid credentials start a Rails-readable session; fetch metadata rejects forgery" do
    assert browser_write(:post, "/session", %{
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
      |> Plug.Conn.put_req_header("sec-fetch-site", "cross-site")
      |> Router.call(Router.init([]))

    assert forged.status == 422
  end

  test "HTTPS login needs metadata, not a token or browser cookie" do
    params = %{"email_address" => "david@37signals.com", "password" => "secret123456"}

    missing =
      conn(
        :post,
        "https://campfire.test/session",
        Map.put(params, "authenticity_token", "legacy-tab-token")
      )
      |> Router.call(Router.init([]))

    assert missing.status == 422

    valid =
      conn(:post, "https://campfire.test/session", params)
      |> Plug.Conn.put_req_header("sec-fetch-site", "same-origin")
      |> Plug.Conn.put_req_header("origin", "https://campfire.test")
      |> Router.call(Router.init([]))

    assert valid.status == 302
    assert valid.resp_cookies["session_token"]
  end

  test "setup form and creation do not generate or require tokens" do
    DB.query("DELETE FROM accounts")
    page = conn(:get, "/first_run") |> Router.call(Router.init([]))
    assert page.status == 200
    refute page.resp_body =~ ~s(name="authenticity_token")
    refute page.resp_body =~ ~s(name="csrf-token")

    response =
      conn(:post, "https://campfire.test/first_run", %{
        "user" => %{
          "name" => "Setup Owner",
          "email_address" => "setup@test.example",
          "password" => "secret123456"
        }
      })
      |> Plug.Conn.put_req_header("sec-fetch-site", "same-origin")
      |> Router.call(Router.init([]))

    assert response.status == 302
    assert DB.one("SELECT id FROM accounts LIMIT 1")
    assert response.resp_cookies["session_token"]
  end

  test "return-to is removed once and the newly signed authentication cookie verifies" do
    c = conn(:get, "/rooms/486777696?before=123") |> Auth.request_authentication()
    cookie = c.resp_cookies["_campfire_session"][:value]
    token = "legacy-tab-token"

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
            browser_write(:post, "/session", %{
              "email_address" => "david@37signals.com",
              "password" => "bad"
            }).status == 401
          )

    assert browser_write(:post, "/session", %{
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
    assert browser_write(:put, "/session/transfers/" <> good, %{}).status == 302
    wrong = Rails.signed_id("User", 127_326_141, "avatar")
    assert browser_write(:put, "/session/transfers/" <> wrong, %{}).status == 400
    expired = Rails.signed_id("User", 127_326_141, "transfer", "2026-03-02T15:59:59Z")
    assert browser_write(:put, "/session/transfers/" <> expired, %{}).status == 400
    DB.query("UPDATE users SET status=1 WHERE id=127326141")
    assert browser_write(:put, "/session/transfers/" <> good, %{}).status == 400
  end
end
