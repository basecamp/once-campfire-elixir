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

  describe "in-process queue" do
    setup do
      start_supervised!({Task.Supervisor, name: Campfire.JobTasks})
      :ok
    end

    defp start_worker(options) do
      test = self()

      perform = fn job ->
        send(test, {:started, job["arguments"], self()})

        receive do
          :release -> :ok
        end
      end

      options = Keyword.merge([concurrency: 1, perform: perform], options)
      start_supervised!(Supervisor.child_spec({Worker, options}, restart: :temporary))
    end

    defp job(class, id), do: %{"job_class" => class, "arguments" => [id]}

    test "runs jobs in order with per-class concurrency, so slow classes do not block others" do
      start_worker([])
      Worker.enqueue(job("Bot::WebhookJob", 1))
      Worker.enqueue(job("Bot::WebhookJob", 2))
      Worker.enqueue(job("Room::PushMessageJob", 3))

      assert_receive {:started, [1], webhook}
      assert_receive {:started, [3], push}
      refute_receive {:started, [2], _}

      send(push, :release)
      send(webhook, :release)
      assert_receive {:started, [2], webhook}
      send(webhook, :release)
    end

    test "runs up to the configured concurrency of one class at once" do
      start_worker(concurrency: 2)
      for id <- 1..3, do: Worker.enqueue(job("Bot::WebhookJob", id))

      assert_receive {:started, [1], first}
      assert_receive {:started, [2], second}
      refute_receive {:started, [3], _}, 100

      send(first, :release)
      assert_receive {:started, [3], third}
      send(second, :release)
      send(third, :release)
    end

    test "drops and logs jobs enqueued onto a full queue" do
      start_worker(capacity: 1)

      log =
        capture_log(fn ->
          Worker.enqueue(job("Bot::WebhookJob", 1))
          assert_receive {:started, [1], running}
          Worker.enqueue(job("Bot::WebhookJob", 2))
          Worker.enqueue(job("Bot::WebhookJob", 3))
          :sys.get_state(Worker)
          send(running, :release)
          assert_receive {:started, [2], queued}
          send(queued, :release)
          refute_receive {:started, [3], _}
        end)

      assert log =~ "Campfire job queue is full, dropping job: Bot::WebhookJob"
    end

    test "logs failures and crashes without retrying or stopping the runner" do
      test = self()

      perform = fn
        %{"arguments" => [:raise]} -> raise "boom"
        %{"arguments" => [:error]} -> {:error, :refused}
        %{"arguments" => [:exit]} -> exit(:crashed)
        %{"arguments" => [id]} -> send(test, {:performed, id})
      end

      start_supervised!({Worker, concurrency: 1, perform: perform})

      log =
        capture_log(fn ->
          for id <- [:raise, :error, :exit, :ok], do: Worker.enqueue(job("Bot::WebhookJob", id))
          assert_receive {:performed, :ok}
          :sys.get_state(Worker)
        end)

      assert log =~ "Campfire job failed: Bot::WebhookJob boom"
      assert log =~ "Campfire job failed: Bot::WebhookJob :refused"
      assert log =~ "Campfire job crashed: Bot::WebhookJob :crashed"
    end

    test "shutdown runs queued jobs and waits for running ones before stopping" do
      start_worker([])
      Worker.enqueue(job("Bot::WebhookJob", 1))
      Worker.enqueue(job("Bot::WebhookJob", 2))
      assert_receive {:started, [1], first}

      stopping = Task.async(fn -> GenServer.stop(Worker, :shutdown) end)
      refute_receive {:started, [2], _}, 100
      send(first, :release)
      assert_receive {:started, [2], second}
      refute Task.yield(stopping, 100)
      send(second, :release)
      assert Task.await(stopping) == :ok
    end

    test "shutdown abandons jobs still unfinished at the deadline" do
      start_worker(drain_ms: 100)
      Worker.enqueue(job("Bot::WebhookJob", 1))
      Worker.enqueue(job("Bot::WebhookJob", 2))
      assert_receive {:started, [1], _}

      log = capture_log(fn -> assert GenServer.stop(Worker, :shutdown) == :ok end)

      assert log =~
               ~s(Campfire jobs abandoned at shutdown: ["Bot::WebhookJob", "Bot::WebhookJob"])
    end

    test "enqueue goes to the in-process worker unless jobs are disabled" do
      adapter = System.get_env("CAMPFIRE_JOBS_ADAPTER")

      on_exit(fn ->
        if adapter,
          do: System.put_env("CAMPFIRE_JOBS_ADAPTER", adapter),
          else: System.delete_env("CAMPFIRE_JOBS_ADAPTER")
      end)

      start_worker([])
      System.put_env("CAMPFIRE_JOBS_ADAPTER", "disabled")
      assert Jobs.enqueue("Bot::WebhookJob", [1]) == :ok
      refute_receive {:started, _, _}, 50

      System.delete_env("CAMPFIRE_JOBS_ADAPTER")
      assert Jobs.enqueue("Bot::WebhookJob", [2]) == :ok
      assert_receive {:started, [2], running}
      send(running, :release)
    end
  end
end
