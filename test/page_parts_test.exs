defmodule Campfire.PagePartsTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn, only: [put_req_header: 3, get_resp_header: 2]
  alias Campfire.{Auth, DB, Router}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  @user 127_326_141
  @room 486_777_696

  setup do
    DB.restore_fixture(@fixture)
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T16:00:00Z")
    on_exit(fn -> System.delete_env("CAMPFIRE_CLOCK") end)
    user = DB.one("SELECT * FROM users WHERE id=?", [@user])
    raw = (conn(:get, "/") |> Auth.start_session(user)).resp_cookies["session_token"][:value]
    %{user: user, cookie: raw}
  end

  defp get(path, cookie, encoding) do
    conn(:get, path)
    |> put_req_cookie("session_token", cookie)
    |> put_req_header("accept-encoding", encoding)
    |> Router.call(Router.init([]))
  end

  defp body(conn), do: IO.iodata_to_binary(conn.resp_body)

  # A gzipped response decodes to exactly the identity response, and its ETag is stable.
  defp assert_spliced(path, cookie, contains) do
    identity = get(path, cookie, "identity")
    gzipped = get(path, cookie, "gzip")
    again = get(path, cookie, "gzip")

    assert identity.status == 200 and gzipped.status == 200
    assert body(identity) =~ contains
    assert get_resp_header(gzipped, "content-encoding") == ["gzip"]
    assert :zlib.gunzip(body(gzipped)) == body(identity)
    assert :zlib.gunzip(body(again)) == body(identity)
    assert get_resp_header(again, "etag") == get_resp_header(gzipped, "etag")
    assert [_] = get_resp_header(gzipped, "etag")
  end

  test "the messages page is spliced from cached fragment pieces", %{cookie: cookie} do
    before = DB.one("SELECT id FROM messages WHERE room_id=? ORDER BY created_at DESC", [@room])
    assert_spliced("/rooms/#{@room}/messages?before=#{before["id"]}", cookie, "message__body")
  end

  test "the search page is spliced from cached fragment pieces", %{cookie: cookie} do
    assert_spliced("/searches?q=sure", cookie, "When we are not sure")
  end

  test "a room page's per-request text is compressed once and reused", %{cookie: cookie} do
    :ets.match_delete(Campfire.FragmentCache.Memo, {{:raw_piece, :_, :_}, :_, :_, :_, :_})
    assert_spliced("/rooms/#{@room}", cookie, "message__body")

    assert :ets.select_count(Campfire.FragmentCache.Memo, [
             {{{:raw_piece, :_, :_}, :_, :_, :_, :_}, [], [true]}
           ]) > 0
  end

  test "the sidebar's batched members render each direct room as the per-room query does",
       %{user: user, cookie: cookie} do
    html = body(get("/users/me/sidebar", cookie, "identity"))

    directs =
      DB.query(
        "SELECT r.*,m.unread_at FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? AND r.type='Rooms::Direct' AND m.involvement!='invisible'",
        [@user]
      )

    assert directs != []

    for room <- directs,
        do: assert(html =~ String.trim(Campfire.Sidebar.render_direct(room, user)))
  end

  test "memoized and compiled values match their direct computation", %{user: user} do
    assert Campfire.Mentions.avatar_token(user) ==
             Campfire.Rails.signed_id("User", user["id"], "avatar")

    assert Campfire.Mentions.avatar_token(user) == Campfire.Mentions.avatar_token(user)
    assert Campfire.Assets.path("lifebuoy.svg") =~ ~r{\A/assets/lifebuoy-[0-9a-f]+\.svg\z}
    assert_raise KeyError, fn -> Campfire.Assets.path("missing.svg") end
    assert Campfire.Chat.digits("2026-03-02 16:00:00.123456") == "20260302160000123456"

    assert Campfire.Assets.html_escape(~s(<a href="x">'&'</a>)) ==
             "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;"
  end

  test "a room page's shell is kept by its inputs and misses when they change", %{cookie: cookie} do
    first = body(get("/rooms/#{@room}", cookie, "identity"))
    assert body(get("/rooms/#{@room}", cookie, "identity")) == first

    DB.query("UPDATE rooms SET name=? WHERE id=?", ["Renamed for the shell test", @room])
    renamed = body(get("/rooms/#{@room}", cookie, "identity"))
    assert renamed =~ "Renamed for the shell test"
    refute first =~ "Renamed for the shell test"
  end

  test "paging from an anchor matches the direct query, with 204 and 404 kept", %{cookie: cookie} do
    [newest | _] =
      DB.query("SELECT * FROM messages WHERE room_id=? ORDER BY created_at DESC", [@room])

    oldest = DB.one("SELECT * FROM messages WHERE room_id=? ORDER BY created_at LIMIT 1", [@room])
    room = DB.one("SELECT * FROM rooms WHERE id=?", [@room])

    expected =
      DB.query(
        "SELECT * FROM messages WHERE room_id=? AND created_at < ? ORDER BY created_at DESC LIMIT 40",
        [@room, newest["created_at"]]
      )
      |> Enum.reverse()

    assert Campfire.Chat.messages(room, %{"before" => to_string(newest["id"])}) == expected

    assert get("/rooms/#{@room}/messages?before=#{oldest["id"]}", cookie, "identity").status ==
             204

    assert get("/rooms/#{@room}/messages?before=1", cookie, "identity").status == 404
  end

  test "a kept session cookie verification still rejects tampering and expiry", %{cookie: cookie} do
    lookup = fn raw ->
      {_, user, _} =
        conn(:get, "/") |> put_req_cookie("session_token", raw) |> Auth.session_lookup()

      user
    end

    assert lookup.(cookie)["id"] == @user
    assert lookup.(cookie)["id"] == @user
    refute lookup.(String.replace_suffix(cookie, String.last(cookie), "0") <> "0")

    System.put_env("CAMPFIRE_CLOCK", "2050-01-01T00:00:00Z")
    refute lookup.(cookie)
  end

  test "timestamp digits take the fast path for SQLite timestamps and match the general one" do
    for value <- [
          "2026-03-02 16:00:00",
          "2026-03-02 16:00:00.123456",
          "2026-03-02T16:00:00Z",
          "x9"
        ] do
      assert Campfire.Chat.digits(value) ==
               for(<<c <- value>>, c in ?0..?9, into: "", do: <<c>>)
    end
  end

  test "the kept sidebar is replaced when a room it lists is renamed", %{cookie: cookie} do
    first = body(get("/users/me/sidebar", cookie, "identity"))
    assert body(get("/users/me/sidebar", cookie, "identity")) == first

    room =
      DB.one(
        "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? AND r.type!='Rooms::Direct' LIMIT 1",
        [@user]
      )

    DB.query("UPDATE rooms SET name=? WHERE id=?", ["Sidebar rename", room["id"]])
    assert body(get("/users/me/sidebar", cookie, "identity")) =~ "Sidebar rename"
  end

  test "the kept search shell is replaced when a recent search is added", %{cookie: cookie} do
    first = body(get("/searches?q=sure", cookie, "identity"))
    assert body(get("/searches?q=sure", cookie, "identity")) == first
    refute first =~ "a brand new query"

    now = "2026-03-02 16:00:00"

    DB.query(
      "INSERT INTO searches (user_id,query,created_at,updated_at) VALUES (?,?,?,?)",
      [@user, "a brand new query", now, now]
    )

    assert body(get("/searches?q=sure", cookie, "identity")) =~ "a brand new query"
  end

  test "a posted message's fragment, rendered from the request's records, matches a fresh render",
       %{cookie: cookie} do
    response =
      conn(:post, "/rooms/#{@room}/messages", %{
        "message" => %{
          "body" => "<div>Hello <strong>there</strong></div>",
          "client_message_id" => "preload-test"
        }
      })
      |> put_req_cookie("session_token", cookie)
      |> put_req_header("sec-fetch-site", "same-origin")
      |> put_req_header("accept", "text/vnd.turbo-stream.html, text/html")
      |> Router.call(Router.init([]))

    assert response.status == 200
    message = DB.one("SELECT * FROM messages WHERE client_message_id='preload-test'")
    posted = Campfire.MessagesView.render(message, "http://www.example.com")
    assert body(response) =~ String.trim_trailing(posted, "\n")

    :ets.delete(Campfire.FragmentCache, {:message, message["id"]})
    assert Campfire.MessagesView.render(message, "http://www.example.com") == posted
  end
end
