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
    :ets.match_delete(Campfire.FragmentCache, {{:raw_piece, :_, :_}, :_, :_, :_})
    assert_spliced("/rooms/#{@room}", cookie, "message__body")

    assert :ets.select_count(Campfire.FragmentCache, [
             {{{:raw_piece, :_, :_}, :_, :_, :_}, [], [true]}
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
end
