defmodule Campfire.CacheHitPathTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test
  alias Campfire.{Auth, DB, Endpoint, Rails, ResponseCache}
  alias Exqlite.Sqlite3, as: SQL
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    DB.restore_fixture(@fixture)
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T16:00:00Z")
    System.put_env("CAMPFIRE_RESPONSE_CACHE_MB", "64")
    ResponseCache.clear()

    on_exit(fn ->
      ResponseCache.cleanup()
      System.delete_env("CAMPFIRE_CLOCK")
      System.delete_env("CAMPFIRE_RESPONSE_CACHE_MB")
    end)

    user = DB.one("SELECT * FROM users WHERE id=127326141")
    room = DB.one("SELECT * FROM rooms WHERE id=486777696")
    session = Auth.start_session(conn(:get, "/"), user).resp_cookies["session_token"].value
    data = %{"session_id" => "hit-path-test", "_csrf_token" => Rails.csrf_token()}
    csrf = Auth.set_browser_session(conn(:get, "/"), data).resp_cookies["_campfire_session"].value
    {:ok, foreign} = SQL.open(System.fetch_env!("DATABASE_PATH"))
    on_exit(fn -> SQL.close(foreign) end)
    %{user: user, room: room, session: session, csrf: csrf, foreign: foreign}
  end

  defp get(context, path, headers \\ []) do
    Enum.reduce(headers, conn(:get, path), fn {name, value}, conn ->
      put_req_header(conn, name, value)
    end)
    |> put_req_cookie("session_token", context.session)
    |> put_req_cookie("_campfire_session", context.csrf)
    |> Endpoint.call(Endpoint.init([]))
  end

  # The processes a request's work goes through: the cache owner, this process's read
  # partition and the writer. Counting their inbound messages counts a request's calls.
  defp owner, do: [Process.whereis(ResponseCache)]

  defp database,
    do: [
      GenServer.whereis({:via, PartitionSupervisor, {DB.ReadPool, self()}}),
      Process.whereis(DB)
    ]

  defp messages_in(pids) do
    Enum.sum(
      for pid <- pids do
        {:ok, stats} = :sys.statistics(pid, :get)
        Keyword.fetch!(stats, :messages_in)
      end
    )
  end

  # Returns `{result, owner_calls, database_calls}`.
  defp count_messages(fun) do
    for pid <- owner() ++ database(), do: :sys.statistics(pid, true)
    {owner_before, database_before} = {messages_in(owner()), messages_in(database())}
    result = fun.()
    counts = {messages_in(owner()) - owner_before, messages_in(database()) - database_before}
    for pid <- owner() ++ database(), do: :sys.statistics(pid, false)
    {result, elem(counts, 0), elem(counts, 1)}
  end

  test "a warm page costs two owner calls and no database query", context do
    for path <- ["/rooms/#{context.room["id"]}", "/searches", "/users/me/sidebar"] do
      assert get(context, path).status == 200, path
      {hit, calls, queries} = count_messages(fn -> get(context, path) end)
      assert hit.status == 200 and hit.assigns[:response_cache_hit], path
      assert calls == 2, "#{path}: only the epoch snapshot and its revalidation reach the owner"
      assert queries == 0, "#{path}: the session, user and room come from the table"
    end

    # The authorization rows are remembered under the epoch: the hit path's session and
    # room lookups resolve from the table rather than from SQLite.
    epoch = ResponseCache.epoch()

    assert [{_, {user, _session}}] =
             :ets.match_object(ResponseCache.Authorization, {{epoch, :session, :_}, :_})

    assert user["id"] == context.user["id"]

    assert [{{^epoch, :room, _, _}, room}] =
             :ets.match_object(ResponseCache.Authorization, {{epoch, :room, :_, :_}, :_})

    assert room["id"] == context.room["id"]
  end

  test "routes without fragments never call the owner", context do
    for path <- ["/up", "/users/#{Rails.signed_id("User", context.user["id"], "avatar")}/avatar"] do
      {response, calls, _} = count_messages(fn -> get(context, path) end)
      assert response.status == 200, path
      assert calls == 0, path
    end
  end

  test "a foreign commit retires remembered authorization and entries", context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200
    assert get(context, path).assigns[:response_cache_hit]
    assert :ets.info(ResponseCache.Authorization, :size) > 0
    assert :ets.info(ResponseCache.Entries, :size) == 1

    :ok =
      SQL.execute(
        context.foreign,
        "UPDATE users SET name='Renamed elsewhere' WHERE id=#{context.user["id"]}"
      )

    renamed = get(context, path)
    refute renamed.assigns[:response_cache_hit]
    assert renamed.resp_body =~ "Renamed elsewhere"

    assert :ets.match_object(
             ResponseCache.Authorization,
             {{ResponseCache.epoch(), :session, :_}, :_}
           ) != []

    assert get(context, path).assigns[:response_cache_hit]

    :ok = SQL.execute(context.foreign, "DELETE FROM sessions WHERE user_id=#{context.user["id"]}")
    assert get(context, path).status == 302
    assert :ets.info(ResponseCache.Entries, :size) == 0
  end

  test "a commit by the request itself, after its capture, is observed before serving",
       context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200
    assert get(context, path).assigns[:response_cache_hit]
    epoch = ResponseCache.epoch()

    # Nothing has committed, so the remembered session is still valid under the epoch, but
    # by the clock it is now idle: resuming it commits between the capture and the lookup.
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T18:00:00Z")
    {resumed, calls, queries} = count_messages(fn -> get(context, path) end)
    assert resumed.status == 200
    refute resumed.assigns[:response_cache_hit]
    assert ResponseCache.epoch() != epoch
    assert calls == 6, "capture, revalidation, recapture, revalidation, fragment check, admission"
    assert queries > 0, "the retry authenticates from the database"

    assert DB.one(
             "SELECT last_active_at FROM sessions WHERE user_id=? ORDER BY id DESC LIMIT 1",
             [context.user["id"]]
           )["last_active_at"] == "2026-03-02 18:00:00"

    assert get(context, path).assigns[:response_cache_hit]
  end

  test "a session deleted after the guard's lookup is not trusted by the cache plug",
       context do
    # A cold page authenticates from the database in the browser guard; a session deleted
    # between that lookup and the cache plug must still be noticed, as it was when the plug
    # authenticated a second time.
    conn =
      conn(:get, "/searches")
      |> put_req_cookie("session_token", context.session)
      |> put_req_cookie("_campfire_session", context.csrf)

    {conn, user, _session} = ResponseCache.authenticate(conn)
    assert user["id"] == context.user["id"]
    assert conn.assigns[:response_cache_auth]
    :ok = SQL.execute(context.foreign, "DELETE FROM sessions WHERE user_id=#{context.user["id"]}")
    conn = ResponseCache.call(conn, [])
    refute conn.halted
    refute conn.assigns[:response_cache_auth]
    refute conn.assigns[:response_cache_capture]
  end

  test "clearing retires every captured epoch", context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200
    assert get(context, path).assigns[:response_cache_hit]
    epoch = ResponseCache.epoch()
    assert ResponseCache.current?(epoch)
    ResponseCache.clear()
    refute ResponseCache.current?(epoch)
    refute get(context, path).assigns[:response_cache_hit]
    assert get(context, path).assigns[:response_cache_hit]
  end

  test "the unsupported-browser page reads its rows from the database", context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200
    assert get(context, path).assigns[:response_cache_hit]
    blocked = [{"user-agent", "Mozilla/5.0 (Windows NT 10.0; Trident/7.0; rv:11.0) like Gecko"}]
    page = get(context, path, blocked)
    assert page.status == 200 and page.halted
    assert page.resp_body =~ "Unsupported browser"
    {_, _, queries} = count_messages(fn -> get(context, path, blocked) end)
    assert queries > 0
  end

  test "a foreign membership removal takes effect on the next request", context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200
    assert get(context, path).assigns[:response_cache_hit]

    :ok =
      SQL.execute(
        context.foreign,
        "DELETE FROM memberships WHERE user_id=#{context.user["id"]} AND room_id=#{context.room["id"]}"
      )

    removed = get(context, path)
    refute removed.status == 200
    refute removed.assigns[:response_cache_hit]
  end

  test "requests keep working across an owner restart", context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).assigns[:response_cache_hit] == nil
    assert get(context, path).assigns[:response_cache_hit]
    owner = Process.whereis(ResponseCache)
    Process.exit(owner, :kill)
    wait_for_owner(owner)
    first = get(context, path)
    assert first.status == 200
    refute first.assigns[:response_cache_hit]
    assert get(context, path).assigns[:response_cache_hit]
  end

  defp wait_for_owner(old) do
    case Process.whereis(ResponseCache) do
      pid when is_pid(pid) and pid != old -> :ok
      _ -> Process.sleep(5) && wait_for_owner(old)
    end
  end

  test "a full authorization table stops remembering until the next commit", context do
    epoch = ResponseCache.epoch()
    for n <- 1..4096, do: :ets.insert(ResponseCache.Authorization, {{epoch, :room, n, "x"}, nil})
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200
    assert :ets.info(ResponseCache.Authorization, :size) == 4096
    assert get(context, path).assigns[:response_cache_hit]
    DB.query("UPDATE users SET name='Committed' WHERE id=?", [context.user["id"]])
    assert get(context, path).status == 200
    assert :ets.info(ResponseCache.Authorization, :size) == 2
    assert get(context, path).assigns[:response_cache_hit]
  end

  test "an idle session is still resumed on a warm hit", context do
    path = "/rooms/#{context.room["id"]}"
    assert get(context, path).status == 200
    assert get(context, path).assigns[:response_cache_hit]

    DB.query("UPDATE sessions SET last_active_at='2026-03-01 00:00:00' WHERE user_id=?", [
      context.user["id"]
    ])

    assert get(context, path).status == 200

    assert DB.one(
             "SELECT last_active_at FROM sessions WHERE user_id=? ORDER BY id DESC LIMIT 1",
             [context.user["id"]]
           )["last_active_at"] == "2026-03-02 16:00:00"
  end

  test "entries and authorization stay bounded and the budget still evicts", context do
    System.put_env("CAMPFIRE_RESPONSE_CACHE_MB", "1")
    epoch = ResponseCache.epoch()
    entry = %{body: String.duplicate("x", 400_000), headers: [], cookies: []}
    for key <- ["one", "two", "three"], do: ResponseCache.put(key, epoch, entry)
    assert ResponseCache.get("one", epoch) == nil
    assert ResponseCache.get("three", epoch) != nil
    assert :ets.info(ResponseCache.Entries, :size) == 2
    assert :sys.get_state(ResponseCache).bytes <= 1024 * 1024
    assert get(context, "/rooms/#{context.room["id"]}").status == 200
  end
end
