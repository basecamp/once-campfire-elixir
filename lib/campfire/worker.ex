defmodule Campfire.Worker do
  @capacity 1024
  @drain_ms 25_000

  @moduledoc """
  In-process background job runner, replacing Redis and Resque.

  **The queue is not durable.** Queued and running jobs exist only in this
  process's memory, so a crash, a kill or a shutdown that outlasts the drain
  deadline loses them. Previously the container's Redis persisted the Resque
  queue in an append-only file, so queued jobs survived a restart. This
  deliberately matches the Rust port, which makes the same tradeoff
  (`plans/rust-conversion.md`, "Jobs"): pushes, webhooks, media analysis,
  purges and banned-content cleanup are best-effort, and Rails retries none
  of them.

  As in Rust, each job class has its own bounded queue of #{@capacity} jobs and
  up to `JOB_CONCURRENCY` (default 2) running jobs, so slow webhooks cannot
  hold up pushes. A job enqueued onto a full queue is dropped and logged.
  Failures are logged and never retried. On shutdown the runner stops taking
  new jobs, runs what is already queued and waits for running jobs for up to
  #{div(@drain_ms, 1000)} seconds; anything still unfinished is abandoned and
  logged. Jobs run under `Campfire.JobTasks`, which must start before this
  process so that it stops after the drain.
  """
  use GenServer
  require Logger
  alias Campfire.{Cable, Chat, DB, Push, Webhooks}

  def start_link(options), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)

  def child_spec(options),
    do: %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]},
      shutdown: Keyword.get(options, :drain_ms, @drain_ms) + 5_000
    }

  @doc "Enqueues a job without waiting. Dropped when its class's queue is full."
  def enqueue(%{"job_class" => _} = job), do: GenServer.cast(__MODULE__, {:enqueue, job})

  @impl GenServer
  def init(options) do
    Process.flag(:trap_exit, true)

    concurrency =
      Keyword.get_lazy(options, :concurrency, fn ->
        String.to_integer(System.get_env("JOB_CONCURRENCY", "2"))
      end)

    {:ok,
     %{
       queues: %{},
       running: %{},
       capacity: Keyword.get(options, :capacity, @capacity),
       concurrency: max(concurrency, 1),
       drain_ms: Keyword.get(options, :drain_ms, @drain_ms),
       perform: Keyword.get(options, :perform, &perform/1)
     }}
  end

  @impl GenServer
  def handle_cast({:enqueue, %{"job_class" => class} = job}, state) do
    {queue, length} = Map.get(state.queues, class, {:queue.new(), 0})

    if length >= state.capacity do
      Logger.error("Campfire job queue is full, dropping job: #{class}")
      {:noreply, state}
    else
      state = put_in(state.queues[class], {:queue.in(job, queue), length + 1})
      {:noreply, start_jobs(state, class)}
    end
  end

  @impl GenServer
  def handle_info({ref, _result}, state) when is_map_key(state.running, ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finished(state, ref)}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, state) when is_map_key(state.running, ref) do
    Logger.error("Campfire job crashed: #{state.running[ref]} #{inspect(reason)}")
    {:noreply, finished(state, ref)}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Stops taking new jobs (later casts stay unread in the mailbox), then runs
  # the queued ones and waits for all of them until the deadline.
  @impl GenServer
  def terminate(_reason, state) do
    deadline = System.monotonic_time(:millisecond) + state.drain_ms
    state = Enum.reduce(Map.keys(state.queues), state, &start_jobs(&2, &1))
    drain(state, deadline)
  end

  defp drain(state, _deadline) when map_size(state.running) == 0, do: :ok

  defp drain(state, deadline) do
    timeout = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {ref, _result} when is_map_key(state.running, ref) ->
        Process.demonitor(ref, [:flush])
        drain(finished(state, ref), deadline)

      {:DOWN, ref, :process, _, reason} when is_map_key(state.running, ref) ->
        Logger.error("Campfire job crashed: #{state.running[ref]} #{inspect(reason)}")
        drain(finished(state, ref), deadline)
    after
      timeout ->
        abandoned =
          Enum.map(state.running, &elem(&1, 1)) ++
            Enum.flat_map(state.queues, fn {class, {_, length}} ->
              List.duplicate(class, length)
            end)

        Logger.error("Campfire jobs abandoned at shutdown: #{inspect(abandoned)}")
    end
  end

  defp finished(state, ref) do
    {class, running} = Map.pop!(state.running, ref)
    start_jobs(%{state | running: running}, class)
  end

  defp start_jobs(state, class) do
    with true <- Enum.count(state.running, &(elem(&1, 1) == class)) < state.concurrency,
         {queue, length} <- state.queues[class],
         {{:value, job}, queue} <- :queue.out(queue) do
      perform = state.perform
      task = Task.Supervisor.async_nolink(Campfire.JobTasks, fn -> run(perform, job) end)

      queues =
        if length == 1,
          do: Map.delete(state.queues, class),
          else: Map.put(state.queues, class, {queue, length - 1})

      start_jobs(
        %{state | queues: queues, running: Map.put(state.running, task.ref, class)},
        class
      )
    else
      _ -> state
    end
  end

  defp run(perform, job) do
    case perform.(job) do
      {:error, error} ->
        Logger.error("Campfire job failed: #{job["job_class"]} #{inspect(error)}")

      _ ->
        :ok
    end
  rescue
    error ->
      Logger.error("Campfire job failed: #{job["job_class"]} #{Exception.message(error)}")
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
