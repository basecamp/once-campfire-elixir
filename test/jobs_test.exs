defmodule Campfire.JobsTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias Campfire.{Chat, DB, Jobs, Webhooks, Worker}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  setup do
    DB.restore_fixture(@fixture)

    %{
      bot: Chat.bot("394959859-BenderBot123"),
      room: DB.one("SELECT * FROM rooms WHERE id=486777696")
    }
  end

  test "worker removes banned content and FTS rows", %{bot: bot, room: room} do
    message = Chat.create_message(bot, room, "<p>bannedcontentneedle</p>")

    assert Worker.perform(%{
             "job_class" => "RemoveBannedContentJob",
             "arguments" => [%{"_aj_globalid" => "gid://campfire/User/#{bot["id"]}"}]
           }) == :ok

    refute DB.one("SELECT id FROM messages WHERE id=?", [message["id"]])

    assert DB.query(
             "SELECT body FROM message_search_index WHERE message_search_index MATCH 'bannedcontentneedle'"
           ) == []
  end

  test "worker delivers webhook JSON and persists a text reply", %{bot: bot, room: room} do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listen)

    DB.query("UPDATE webhooks SET url=? WHERE user_id=?", [
      "http://127.0.0.1:#{port}/hooks",
      bot["id"]
    ])

    message = Chat.create_message(bot, room, "<p>hello webhook</p>")

    task =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listen)
        {:ok, request} = :gen_tcp.recv(socket, 0, 5000)
        [_, body] = String.split(request, "\r\n\r\n", parts: 2)
        payload = Jason.decode!(body)
        assert payload["message"]["body"]["plain"] == "hello webhook"

        assert payload["room"]["path"] ==
                 "/rooms/#{room["id"]}/#{bot["id"]}-#{bot["bot_token"]}/messages"

        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 10\r\nConnection: close\r\n\r\nhello back"
        )

        :gen_tcp.close(socket)
      end)

    assert is_map(Webhooks.perform(bot, message))
    Task.await(task, 6_000)
    :gen_tcp.close(listen)
    reply = DB.one("SELECT * FROM messages ORDER BY id DESC LIMIT 1")
    assert reply["creator_id"] == bot["id"]
    assert Chat.present_message(reply, "")["body"]["plain_text"] == "hello back"
  end

  test "missing job records fail deserialization rather than silently dropping work" do
    assert_raise RuntimeError, ~r/deserialization failed/, fn ->
      Worker.perform(%{
        "job_class" => "RemoveBannedContentJob",
        "arguments" => [%{"_aj_globalid" => "gid://campfire/User/999999999999"}]
      })
    end
  end

  test "enqueue reports unavailable Redis without exiting the caller" do
    adapter = System.get_env("CAMPFIRE_JOBS_ADAPTER")
    System.delete_env("CAMPFIRE_JOBS_ADAPTER")

    on_exit(fn ->
      if adapter,
        do: System.put_env("CAMPFIRE_JOBS_ADAPTER", adapter),
        else: System.delete_env("CAMPFIRE_JOBS_ADAPTER")
    end)

    assert Process.whereis(Campfire.Redis) == nil

    log =
      capture_log(fn ->
        assert Jobs.enqueue("ExampleJob", []) == {:error, :redis_unavailable}
      end)

    assert log =~ "Campfire job enqueue failed: :redis_unavailable"
  end

  test "enqueue reports a Redis disconnect race without exiting the caller" do
    adapter = System.get_env("CAMPFIRE_JOBS_ADAPTER")
    System.delete_env("CAMPFIRE_JOBS_ADAPTER")

    redis =
      spawn(fn ->
        receive do
          {:"$gen_cast", _request} -> exit(:simulated_disconnect)
        end
      end)

    Process.register(redis, Campfire.Redis)

    on_exit(fn ->
      if Process.alive?(redis), do: Process.exit(redis, :kill)

      if adapter,
        do: System.put_env("CAMPFIRE_JOBS_ADAPTER", adapter),
        else: System.delete_env("CAMPFIRE_JOBS_ADAPTER")
    end)

    log =
      capture_log(fn ->
        assert Jobs.enqueue("ExampleJob", []) ==
                 {:error, {:redis_unavailable, :simulated_disconnect}}
      end)

    assert log =~ "Campfire job enqueue failed: {:redis_unavailable, :simulated_disconnect}"
  end
end
