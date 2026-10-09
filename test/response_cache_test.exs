defmodule Campfire.ResponseCacheTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test
  alias Campfire.{Auth, Chat, DB, Endpoint, Rails, ResponseCache}
  alias Campfire.SQLite, as: SQL
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    DB.restore_fixture(@fixture)
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T16:00:00Z")
    System.put_env("CAMPFIRE_RESPONSE_CACHE_MB", "64")

    on_exit(fn ->
      ResponseCache.cleanup()
      System.delete_env("CAMPFIRE_CLOCK")
      System.delete_env("CAMPFIRE_RESPONSE_CACHE_MB")
    end)

    user = DB.one("SELECT * FROM users WHERE id=127326141")

    room =
      DB.one(
        "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.id LIMIT 1",
        [user["id"]]
      )

    session = Auth.start_session(conn(:get, "/"), user).resp_cookies["session_token"].value
    data = %{"session_id" => "response-cache-test", "_csrf_token" => Rails.csrf_token()}
    csrf = Auth.set_browser_session(conn(:get, "/"), data).resp_cookies["_campfire_session"].value
    {:ok, foreign} = SQL.open(System.fetch_env!("DATABASE_PATH"))
    on_exit(fn -> SQL.close(foreign) end)
    %{user: user, room: room, session: session, csrf: csrf, data: data, foreign: foreign}
  end

  defp request(context, path, headers \\ []) do
    Enum.reduce(headers, conn(:get, path), fn {name, value}, conn ->
      put_req_header(conn, name, value)
    end)
    |> put_req_cookie("session_token", context.session)
    |> put_req_cookie("_campfire_session", context.csrf)
  end

  defp get(context, path, headers \\ []),
    do: request(context, path, headers) |> Endpoint.call(Endpoint.init([]))

  test "hot pages cache exact identity and gzip bytes without token substitution", context do
    literal = "campfire-csrf-input authenticity_token literal-cache-text"
    Chat.create_message(context.user, context.room, literal)
    path = "/rooms/#{context.room["id"]}"

    for headers <- [[], [{"accept-encoding", "gzip"}]] do
      first = get(context, path, headers)
      second = get(context, path, headers)
      assert first.status == 200 && second.status == 200
      assert second.assigns[:response_cache_hit]
      assert first.resp_body == second.resp_body

      body =
        if get_resp_header(second, "content-encoding") == ["gzip"],
          do: :zlib.gunzip(second.resp_body),
          else: second.resp_body

      assert body =~ literal
      refute body =~ ~s(<meta name="csrf-token")
      refute body =~ ~s(name="authenticity_token")
      assert second.resp_cookies["session_token"].value
      assert second.resp_cookies["_campfire_session"].value
      assert second.resp_cookies["last_room"].value == to_string(context.room["id"])
    end
  end

  test "local and foreign unversioned content and presentation writes invalidate", context do
    message = Chat.create_message(context.user, context.room, "before response-cache text")
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).resp_body =~ "before response-cache text"

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE users SET name='Foreign cache name' WHERE id=#{context.user["id"]}; UPDATE accounts SET custom_styles='body { color: red; }'; UPDATE action_text_rich_texts SET body='foreign response-cache text' WHERE record_id=#{message["id"]}"
      )

    after_foreign = get(context, path)
    assert after_foreign.resp_body =~ "Foreign cache name"
    assert after_foreign.resp_body =~ "body { color: red; }"
    assert after_foreign.resp_body =~ "foreign response-cache text"
    refute after_foreign.resp_body =~ "before response-cache text"

    DB.query("UPDATE action_text_rich_texts SET body=? WHERE record_id=?", [
      "local response-cache text",
      message["id"]
    ])

    assert get(context, path).resp_body =~ "local response-cache text"
  end

  test "wildcard HTML requests invalidate timestamp-only fragments after foreign writes",
       context do
    message = Chat.create_message(context.user, context.room, "before wildcard cache text")
    path = "/rooms/#{context.room["id"]}"
    headers = [{"accept", "*/*"}]
    assert get(context, path, headers).resp_body =~ "before wildcard cache text"
    assert get(context, path, headers).assigns[:response_cache_hit]

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE action_text_rich_texts SET body='foreign wildcard cache text' WHERE record_id=#{message["id"]}"
      )

    changed = get(context, path, headers)
    assert changed.resp_body =~ "foreign wildcard cache text"
    refute changed.resp_body =~ "before wildcard cache text"
  end

  test "foreign edits invalidate native fragments with the page cache disabled or conditional",
       context do
    message = Chat.create_message(context.user, context.room, "before native fragment text")
    path = "/rooms/#{context.room["id"]}"
    System.put_env("CAMPFIRE_RESPONSE_CACHE_MB", "0")
    assert get(context, path).resp_body =~ "before native fragment text"

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE action_text_rich_texts SET body='foreign disabled fragment text' WHERE record_id=#{message["id"]}"
      )

    assert get(context, path).resp_body =~ "foreign disabled fragment text"

    System.put_env("CAMPFIRE_RESPONSE_CACHE_MB", "64")
    conditional = [{"if-none-match", "unmatched"}]
    assert get(context, path, conditional).resp_body =~ "foreign disabled fragment text"

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE action_text_rich_texts SET body='foreign conditional fragment text' WHERE record_id=#{message["id"]}"
      )

    changed = get(context, path, conditional)
    assert changed.resp_body =~ "foreign conditional fragment text"
    refute changed.resp_body =~ "foreign disabled fragment text"
  end

  test "an older render cannot populate the newer fragment namespace", context do
    parent = self()

    task =
      Task.async(fn ->
        request(context, "/rooms/#{context.room["id"]}", [{"if-none-match", "unmatched"}])
        |> fetch_cookies()
        |> ResponseCache.call([])

        html =
          Campfire.FragmentCache.fetch(:inflight_fragment, fn ->
            send(parent, :old_render_started)

            receive do
              :finish_old_render -> "old snapshot"
            end
          end)

        ResponseCache.cleanup()
        html
      end)

    assert_receive :old_render_started
    :ok = SQL.execute(context.foreign, "UPDATE accounts SET name='new fragment generation'")

    assert Campfire.FragmentCache.fetch(:inflight_fragment, fn -> "new snapshot" end) ==
             "new snapshot"

    send(task.pid, :finish_old_render)
    assert Task.await(task) == "old snapshot"

    assert Campfire.FragmentCache.fetch(:inflight_fragment, fn -> "should be cached" end) ==
             "new snapshot"
  end

  test "pagination validators follow actual content after foreign writes without timestamps",
       context do
    message = Chat.create_message(context.user, context.room, "before conditional leaf text")
    path = "/rooms/#{context.room["id"]}/messages"
    html = [{"accept", "text/html"}]
    initial = get(context, path, html)
    assert initial.status == 200
    [etag] = get_resp_header(initial, "etag")

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE action_text_rich_texts SET body='foreign conditional leaf text' WHERE record_id=#{message["id"]}"
      )

    changed = get(context, path, html ++ [{"if-none-match", etag}])
    assert changed.status == 200
    assert changed.resp_body =~ "foreign conditional leaf text"
    refute changed.resp_body =~ "before conditional leaf text"
    assert get_resp_header(changed, "etag") != [etag]
    assert get_resp_header(changed, "last-modified") == []
    dated = get(context, path, html ++ [{"if-modified-since", "Tue, 03 Mar 2099 00:00:00 GMT"}])
    assert dated.status == 200
    assert dated.resp_body =~ "foreign conditional leaf text"
    assert get(context, path, html ++ [{"if-none-match", "*"}]).status == 304
  end

  test "warm bodies never replace current membership or authentication", context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200

    :ok =
      SQL.execute(
        context.foreign,
        "DELETE FROM memberships WHERE user_id=#{context.user["id"]} AND room_id=#{context.room["id"]}"
      )

    assert get(context, path).status == 302
    :ok = SQL.execute(context.foreign, "DELETE FROM sessions WHERE user_id=#{context.user["id"]}")
    response = get(context, path)
    assert response.status == 302
    assert get_resp_header(response, "location") == ["http://www.example.com/session/new"]
  end

  test "epochs captured before auth and midrender prevent stale admission", context do
    epoch = ResponseCache.epoch()
    {_, old_user, _} = request(context, "/searches") |> Auth.session_user()

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE users SET name='After auth' WHERE id=#{context.user["id"]}"
      )

    assert ResponseCache.get("race", epoch) == nil

    :ok =
      ResponseCache.put("race", epoch, %{
        body: old_user["name"],
        slots: [],
        headers: [],
        cookies: []
      })

    assert ResponseCache.get("race", ResponseCache.epoch()) == nil
    path = "/rooms/#{context.room["id"]}"
    prepared = request(context, path) |> fetch_query_params() |> ResponseCache.call([])

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE users SET name='After render' WHERE id=#{context.user["id"]}"
      )

    rendered = Campfire.RoomPage.show(prepared, to_string(context.room["id"]))
    assert rendered.status == 200
    ResponseCache.cleanup()
    final = get(context, path)
    refute final.assigns[:response_cache_hit]
    assert final.resp_body =~ "After render"
  end

  test "frame JSON conditional and flash variants retain native paths", context do
    Chat.create_message(context.user, context.room, "format fixture")
    path = "/rooms/#{context.room["id"]}"
    full = get(context, path)
    assert full.resp_body =~ "<!DOCTYPE html>"
    frame = get(context, path, [{"turbo-frame", "messages"}])
    refute frame.resp_body =~ "<!DOCTYPE html>"
    assert get(context, path).assigns[:response_cache_hit]
    messages = get(context, path <> "/messages", [{"accept", "application/json"}])

    assert get_resp_header(messages, "content-type")
           |> Enum.any?(&String.starts_with?(&1, "application/json"))

    refute messages.assigns[:response_cache_hit]
    conditional = get(context, path, [{"if-none-match", "unmatched"}])
    assert conditional.status == 200
    refute conditional.assigns[:response_cache_hit]

    flash_data =
      Map.put(context.data, "flash", %{"discard" => [], "flashes" => %{"notice" => "fresh flash"}})

    flash_cookie =
      Auth.set_browser_session(conn(:get, "/"), flash_data).resp_cookies["_campfire_session"].value

    flashed = get(%{context | csrf: flash_cookie}, path)
    assert flashed.resp_body =~ "fresh flash"
    refute flashed.assigns[:response_cache_hit]
  end

  test "body budget disable and rollback preserve bounded valid entries", context do
    System.put_env("CAMPFIRE_RESPONSE_CACHE_MB", "1")
    epoch = ResponseCache.epoch()
    entry = %{body: String.duplicate("x", 400_000), slots: [], headers: [], cookies: []}
    for key <- ["one", "two", "three"], do: ResponseCache.put(key, epoch, entry)
    assert ResponseCache.get("one", epoch) == nil
    assert ResponseCache.get("three", epoch) != nil
    :ok = SQL.execute(context.foreign, "BEGIN; UPDATE accounts SET name='rolled back'; ROLLBACK")
    assert ResponseCache.epoch() == epoch
    assert ResponseCache.get("three", epoch) != nil
    System.put_env("CAMPFIRE_RESPONSE_CACHE_MB", "0")
    assert ResponseCache.epoch() == nil
    assert get(context, "/rooms/#{context.room["id"]}").status == 200
    assert :sys.get_state(ResponseCache).bytes == 0
  end
end
