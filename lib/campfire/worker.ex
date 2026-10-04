defmodule Campfire.Worker do
  use GenServer
  require Logger
  alias Campfire.{Cable, Chat, DB, Push, Webhooks}
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def child_spec(options),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}, shutdown: 30_000}

  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, hostname} = :inet.gethostname()
    worker = "#{hostname}:#{System.pid()}:default"

    {:ok, _} =
      Redix.transaction_pipeline(Campfire.Redis, [
        ["SADD", "resque:workers", worker],
        [
          "SET",
          "resque:worker:#{worker}:started",
          Calendar.strftime(Campfire.Clock.now(), "%Y-%m-%d %H:%M:%S %z")
        ]
      ])

    send(self(), :poll)
    {:ok, Map.put(state, :worker, worker)}
  end

  def terminate(_, %{worker: worker}) do
    Redix.transaction_pipeline(Campfire.Redis, [
      ["SREM", "resque:workers", worker],
      [
        "DEL",
        "resque:worker:#{worker}",
        "resque:worker:#{worker}:started",
        "resque:stat:processed:#{worker}",
        "resque:stat:failed:#{worker}"
      ]
    ])

    :ok
  end

  def handle_info(:poll, state) do
    claimed = Redix.command(Campfire.Redis, ["LPOP", "resque:queue:default"])

    case claimed do
      {:ok, nil} ->
        :ok

      {:ok, payload} ->
        decoded =
          case Jason.decode(payload) do
            {:ok, decoded} -> decoded
            _ -> %{"raw" => payload}
          end

        current = %{
          "queue" => "default",
          "run_at" => Calendar.strftime(Campfire.Clock.now(), "%Y-%m-%dT%H:%M:%SZ"),
          "payload" => decoded
        }

        Redix.command(Campfire.Redis, [
          "SET",
          "resque:worker:#{state.worker}",
          Jason.encode!(current)
        ])

        try do
          %{"class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper", "args" => [job]} =
            Jason.decode!(payload)

          case perform(job) do
            {:error, error} -> raise "job failed: #{inspect(error)}"
            _ -> :ok
          end
        rescue
          error ->
            Logger.error("Campfire job failed: #{Exception.message(error)}")

            failure = %{
              "failed_at" => Calendar.strftime(Campfire.Clock.now(), "%Y/%m/%d %H:%M:%S UTC"),
              "payload" => decoded,
              "exception" => inspect(error.__struct__),
              "error" => Exception.message(error),
              "backtrace" => Enum.map(__STACKTRACE__, &Exception.format_stacktrace_entry/1),
              "worker" => state.worker,
              "queue" => "default"
            }

            Redix.transaction_pipeline(Campfire.Redis, [
              ["INCR", "resque:stat:failed"],
              ["INCR", "resque:stat:failed:#{state.worker}"],
              ["RPUSH", "resque:failed", Jason.encode!(failure)]
            ])
        after
          Redix.transaction_pipeline(Campfire.Redis, [
            ["INCR", "resque:stat:processed"],
            ["INCR", "resque:stat:processed:#{state.worker}"],
            ["DEL", "resque:worker:#{state.worker}"]
          ])
        end

      {:error, error} ->
        Logger.error("Campfire queue unavailable: #{inspect(error)}")
    end

    Process.send_after(
      self(),
      :poll,
      if(match?({:ok, payload} when is_binary(payload), claimed), do: 0, else: 50)
    )

    {:noreply, state}
  end

  # System.cmd media helpers are linked ports. Their completed exit is already
  # represented by the command result and must not restart the queue consumer.
  def handle_info({:EXIT, port, _reason}, state) when is_port(port), do: {:noreply, state}

  def perform(%{"job_class" => class, "arguments" => arguments}) do
    records = Enum.map(arguments, &record/1)

    case {class, records} do
      {"Room::PushMessageJob", [room, message]} ->
        Push.perform(room, message)

      {"Bot::WebhookJob", [bot, message]} ->
        Webhooks.perform(bot, message)

      {"RemoveBannedContentJob", [user]} ->
        for message <-
              DB.query("SELECT * FROM messages WHERE creator_id=? ORDER BY id", [user["id"]]) do
          room = DB.one("SELECT * FROM rooms WHERE id=?", [message["room_id"]])
          Chat.delete_message(message)

          Cable.broadcast(
            Cable.messages_stream(room),
            ~s(<turbo-stream action="remove" target="message_#{message["client_message_id"]}"></turbo-stream>)
          )
        end

        :ok

      {"ActiveStorage::AnalyzeJob", [blob]} ->
        Campfire.StorageMedia.analyze(blob)

      {"ActiveStorage::PurgeJob", [blob]} ->
        Campfire.Attachments.purge(blob)

      _ ->
        {:error, {:unsupported_job, class}}
    end
  end

  defp record(%{"_aj_globalid" => gid}) do
    uri = URI.parse(gid)
    [model, id] = String.split(uri.path, "/", trim: true)

    table =
      case model do
        "User" -> "users"
        "Message" -> "messages"
        "Room" -> "rooms"
        type when type in ["Rooms::Open", "Rooms::Closed", "Rooms::Direct"] -> "rooms"
        "ActiveStorage::Blob" -> "active_storage_blobs"
      end

    DB.one("SELECT * FROM #{table} WHERE id=?", [Chat.integer(id)]) ||
      raise "ActiveJob deserialization failed: #{gid}"
  end
end
