defmodule Campfire.LocalQueue do
  @moduledoc """
  In-process job queue used when no Redis is configured.

  Jobs are the same Resque-compatible JSON payloads `Campfire.Jobs` builds, consumed by
  `Campfire.Worker` in FIFO order. Jobs are lost if the node stops before draining; the
  Rails deployment had the same window between accepting a request and Resque picking it up.
  """
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_), do: {:ok, %{queue: :queue.new(), queued: 0, processed: 0, failed: 0}}

  def push(payload) when is_binary(payload), do: GenServer.cast(__MODULE__, {:push, payload})
  def claim, do: GenServer.call(__MODULE__, :claim)
  def processed, do: GenServer.cast(__MODULE__, :processed)
  def failed, do: GenServer.cast(__MODULE__, :failed)
  def stats, do: GenServer.call(__MODULE__, :stats)

  def handle_cast({:push, payload}, state),
    do: {:noreply, %{state | queue: :queue.in(payload, state.queue), queued: state.queued + 1}}

  def handle_cast(:processed, state), do: {:noreply, %{state | processed: state.processed + 1}}
  def handle_cast(:failed, state), do: {:noreply, %{state | failed: state.failed + 1}}

  def handle_call(:claim, _, state) do
    case :queue.out(state.queue) do
      {{:value, payload}, queue} ->
        {:reply, {:ok, payload}, %{state | queue: queue, queued: state.queued - 1}}

      {:empty, _} ->
        {:reply, {:ok, nil}, state}
    end
  end

  def handle_call(:stats, _, state) do
    {:reply,
     %{"queued" => state.queued, "processed" => state.processed, "failed" => state.failed}, state}
  end
end
