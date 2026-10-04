defmodule Campfire.ResponseCacheTest do
  use ExUnit.Case, async: false
  import Plug.Test
  alias Campfire.{Chat, DB, Rails, ResponseCache, Router}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  @room 486_777_696

  setup do
    Campfire.RateLimiter.clear()
    DB.restore_fixture(@fixture)
    ResponseCache.clear()
    :ok
  end

  defp login do
    page = conn(:get, "/session/new") |> Router.call(Router.init([]))
    session_cookie = page.resp_cookies["_campfire_session"][:value]
    data = Rails.decrypt_cookie("_campfire_session", URI.decode(session_cookie))

    conn(:post, "/session", %{
      "email_address" => "david@37signals.com",
      "password" => "secret123456",
      "authenticity_token" => Rails.csrf_mask(Rails.csrf_global(data["_csrf_token"]))
    })
    |> put_req_cookie("_campfire_session", session_cookie)
    |> Router.call(Router.init([]))
    |> then(fn response ->
      assert response.status == 302

      %{
        "session_token" => response.resp_cookies["session_token"][:value],
        "_campfire_session" => session_cookie
      }
    end)
  end

  defp get(cookies, path, headers \\ []) do
    conn = conn(:get, path)
    conn = Enum.reduce(cookies, conn, fn {name, value}, c -> put_req_cookie(c, name, value) end)

    conn =
      Enum.reduce(headers, conn, fn {name, value}, c ->
        Plug.Conn.put_req_header(c, name, value)
      end)

    Router.call(conn, Router.init([]))
  end

  test "classifies statements" do
    assert DB.write?("INSERT INTO x VALUES (1)")
    assert DB.write?("  update x set a=1")
    assert DB.write?("DELETE FROM x")
    refute DB.write?("SELECT 1")
    refute DB.write?("\nWITH t AS (SELECT 1) SELECT * FROM t")
    refute DB.write?("PRAGMA foreign_keys")
  end

  test "room page is served from the cache until a write happens" do
    cookies = login()
    first = get(cookies, "/rooms/#{@room}")
    assert first.status == 200
    refute first.assigns[:response_cache_hit]
    assert first.resp_body =~ "data-message-id"

    second = get(cookies, "/rooms/#{@room}")
    assert second.status == 200
    assert second.assigns[:response_cache_hit]
    assert second.resp_body == first.resp_body
    assert Plug.Conn.get_resp_header(second, "etag") == Plug.Conn.get_resp_header(first, "etag")
    assert Plug.Conn.get_resp_header(second, "link") == Plug.Conn.get_resp_header(first, "link")
    assert second.resp_cookies["session_token"]
    assert second.resp_cookies["last_room"][:value] == to_string(@room)

    conditional =
      get(cookies, "/rooms/#{@room}", [
        {"if-none-match", hd(Plug.Conn.get_resp_header(first, "etag"))}
      ])

    assert conditional.status == 304

    gzipped = get(cookies, "/rooms/#{@room}", [{"accept-encoding", "gzip"}])
    assert Plug.Conn.get_resp_header(gzipped, "content-encoding") == ["gzip"]
    assert :zlib.gunzip(gzipped.resp_body) == first.resp_body
    again = get(cookies, "/rooms/#{@room}", [{"accept-encoding", "gzip"}])
    assert :zlib.gunzip(again.resp_body) == first.resp_body

    room = DB.one("SELECT * FROM rooms WHERE id=?", [@room])
    user = DB.one("SELECT * FROM users WHERE id=127326141")
    message = Chat.create_message(user, room, "<p>freshly posted</p>")
    assert is_map(message)

    third = get(cookies, "/rooms/#{@room}")
    refute third.assigns[:response_cache_hit]
    assert third.resp_body =~ "freshly posted"
    refute first.resp_body =~ "freshly posted"
  end

  test "other users and sessions never share entries" do
    david = login()
    first = get(david, "/users/me/sidebar", [{"turbo-frame", "user_sidebar"}])
    assert first.status == 200

    assert get(david, "/users/me/sidebar", [{"turbo-frame", "user_sidebar"}]).assigns[
             :response_cache_hit
           ]

    other = login()

    refute get(other, "/users/me/sidebar", [{"turbo-frame", "user_sidebar"}]).assigns[
             :response_cache_hit
           ]

    assert get(other, "/users/me/sidebar", [{"turbo-frame", "user_sidebar"}]).assigns[
             :response_cache_hit
           ]
  end

  test "messages page keys on the message versions" do
    cookies = login()

    before =
      DB.query("SELECT id FROM messages WHERE room_id=? ORDER BY created_at", [@room])
      |> Enum.at(59)

    path = "/rooms/#{@room}/messages?before=#{before["id"]}"
    first = get(cookies, path)
    assert first.status == 200
    assert get(cookies, path).assigns[:response_cache_hit]
    assert get(cookies, path).resp_body == first.resp_body
  end

  test "static assets are served identically from the compressed cache" do
    path = Campfire.Assets.path("_reset.css")

    first = get([], path, [{"accept-encoding", "gzip"}])
    assert first.status == 200
    assert Plug.Conn.get_resp_header(first, "content-encoding") == ["gzip"]
    second = get([], path, [{"accept-encoding", "gzip"}])
    assert :zlib.gunzip(second.resp_body) == :zlib.gunzip(first.resp_body)

    assert Plug.Conn.get_resp_header(second, "last-modified") ==
             Plug.Conn.get_resp_header(first, "last-modified")

    assert get([], path).resp_body == :zlib.gunzip(first.resp_body)
  end
end
