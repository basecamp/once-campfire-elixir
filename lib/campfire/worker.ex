defmodule Campfire.Worker do
  @moduledoc """
  In-process background job queue. Jobs run under `Campfire.JobTasks` with at
  most `JOB_CONCURRENCY` (default 2) at a time, in enqueue order; failures are
  logged. Like the container's non-persistent Redis it replaces, queued jobs do
  not survive a restart.
  """
  use GenServer
  require Logger
  alias Campfire.{Cable, Chat, DB, Push, Webhooks}

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def child_spec(options),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}, shutdown: 30_000}

  def enqueue(job), do: GenServer.cast(__MODULE__, {:enqueue, job})

  @impl GenServer
  def init(nil) do
    concurrency = String.to_integer(System.get_env("JOB_CONCURRENCY", "2"))
    {:ok, %{queue: :queue.new(), running: %{}, concurrency: max(concurrency, 1)}}
  end

  @impl GenServer
  def handle_cast({:enqueue, job}, state),
    do: {:noreply, start_jobs(%{state | queue: :queue.in(job, state.queue)})}

  @impl GenServer
  def handle_info({ref, _result}, state) when is_map_key(state.running, ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, start_jobs(%{state | running: Map.delete(state.running, ref)})}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, state) when is_map_key(state.running, ref) do
    Logger.error(
      "Campfire job crashed: #{inspect(state.running[ref]["job_class"])} #{inspect(reason)}"
    )

    {:noreply, start_jobs(%{state | running: Map.delete(state.running, ref)})}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp start_jobs(state) do
    with true <- map_size(state.running) < state.concurrency,
         {{:value, job}, queue} <- :queue.out(state.queue) do
      task = Task.Supervisor.async_nolink(Campfire.JobTasks, fn -> run(job) end)
      start_jobs(%{state | queue: queue, running: Map.put(state.running, task.ref, job)})
    else
      _ -> state
    end
  end

  defp run(job) do
    case perform(job) do
      {:error, error} ->
        Logger.error("Campfire job failed: #{job["job_class"]} #{inspect(error)}")

      _ ->
        :ok
    end
  rescue
    error -> Logger.error("Campfire job failed: #{job["job_class"]} #{Exception.message(error)}")
  end

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
