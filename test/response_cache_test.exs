defmodule Campfire.ResponseCacheTest do
  use ExUnit.Case, async: false
  import Plug.Test
  alias Campfire.{Chat, DB, Rails, ResponseCache, Router}
  alias Exqlite.Sqlite3, as: SQL
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

  defp hit?(conn), do: conn.assigns[:response_cache_hit] != nil

  test "generation follows SQLite's data version" do
    before = ResponseCache.generation()
    assert ResponseCache.generation() == before

    assert [_] =
             DB.query(
               "UPDATE accounts SET name=name||'!' WHERE id IN (SELECT id FROM accounts LIMIT 1) RETURNING id"
             )

    assert ResponseCache.generation() != before
  end

  test "room page is served from the cache until this node writes" do
    cookies = login()
    first = get(cookies, "/rooms/#{@room}")
    assert first.status == 200
    refute hit?(first)
    assert first.resp_body =~ "data-message-id"

    second = get(cookies, "/rooms/#{@room}")
    assert second.status == 200
    assert hit?(second)
    assert second.resp_body == first.resp_body
    assert Plug.Conn.get_resp_header(second, "etag") == Plug.Conn.get_resp_header(first, "etag")
    assert Plug.Conn.get_resp_header(second, "link") == Plug.Conn.get_resp_header(first, "link")
    assert second.resp_cookies["session_token"]
    assert second.resp_cookies["last_room"][:value] == to_string(@room)

    etag = hd(Plug.Conn.get_resp_header(first, "etag"))
    assert get(cookies, "/rooms/#{@room}", [{"if-none-match", etag}]).status == 304

    gzipped = get(cookies, "/rooms/#{@room}", [{"accept-encoding", "gzip"}])
    assert Plug.Conn.get_resp_header(gzipped, "content-encoding") == ["gzip"]
    assert :zlib.gunzip(gzipped.resp_body) == first.resp_body
    again = get(cookies, "/rooms/#{@room}", [{"accept-encoding", "gzip"}])
    assert hit?(again)
    assert :zlib.gunzip(again.resp_body) == first.resp_body

    room = DB.one("SELECT * FROM rooms WHERE id=?", [@room])
    user = DB.one("SELECT * FROM users WHERE id=127326141")
    assert is_map(Chat.create_message(user, room, "<p>freshly posted</p>"))

    third = get(cookies, "/rooms/#{@room}")
    refute hit?(third)
    assert third.resp_body =~ "freshly posted"
    refute first.resp_body =~ "freshly posted"
  end

  test "a write from another connection invalidates cached pages" do
    cookies = login()
    assert get(cookies, "/rooms/#{@room}").status == 200
    assert hit?(get(cookies, "/rooms/#{@room}"))

    # Another SQLite connection, as a separate job node or a Rails process would use.
    {:ok, other} = SQL.open(System.fetch_env!("DATABASE_PATH"))

    :ok =
      SQL.execute(
        other,
        "UPDATE rooms SET name='Renamed elsewhere', updated_at='2026-03-02 17:00:00' WHERE id=#{@room}"
      )

    :ok = SQL.close(other)

    renamed = get(cookies, "/rooms/#{@room}")
    refute hit?(renamed)
    assert renamed.resp_body =~ "Renamed elsewhere"
    assert hit?(get(cookies, "/rooms/#{@room}"))
  end

  if System.find_executable("sqlite3") do
    test "a write from another operating-system process invalidates cached pages" do
      cookies = login()
      assert get(cookies, "/rooms/#{@room}").status == 200
      assert hit?(get(cookies, "/rooms/#{@room}"))

      {_, 0} =
        System.cmd("sqlite3", [
          System.fetch_env!("DATABASE_PATH"),
          "UPDATE rooms SET name='Renamed by sqlite3', updated_at='2026-03-02 17:00:00' WHERE id=#{@room}"
        ])

      renamed = get(cookies, "/rooms/#{@room}")
      refute hit?(renamed)
      assert renamed.resp_body =~ "Renamed by sqlite3"
    end
  end

  test "other users and sessions never share entries" do
    david = login()
    frame = [{"turbo-frame", "user_sidebar"}]
    assert get(david, "/users/me/sidebar", frame).status == 200
    assert hit?(get(david, "/users/me/sidebar", frame))

    other = login()
    refute hit?(get(other, "/users/me/sidebar", frame))
    assert hit?(get(other, "/users/me/sidebar", frame))
  end

  test "messages page keys on the message versions" do
    cookies = login()

    before =
      DB.query("SELECT id FROM messages WHERE room_id=? ORDER BY created_at", [@room])
      |> Enum.at(59)

    path = "/rooms/#{@room}/messages?before=#{before["id"]}"
    first = get(cookies, path)
    assert first.status == 200
    assert hit?(get(cookies, path))
    assert get(cookies, path).resp_body == first.resp_body
  end

  test "flash messages bypass the cache" do
    cookies = login()
    assert get(cookies, "/rooms/#{@room}").status == 200
    assert hit?(get(cookies, "/rooms/#{@room}"))

    redirect = get(cookies, "/rooms/999999999")
    assert redirect.status == 302

    flashed =
      Map.put(cookies, "_campfire_session", redirect.resp_cookies["_campfire_session"][:value])

    page = get(flashed, "/rooms/#{@room}")
    assert page.status == 200
    refute hit?(page)
    assert page.resp_body =~ "Room not found or inaccessible"
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
