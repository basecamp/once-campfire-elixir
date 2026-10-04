defmodule Campfire.CableFrames do
  @moduledoc "Reuse identical outgoing frames across authorized subscribers."
  use GenServer
  @capacity 4096
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    :ets.new(__MODULE__, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, :queue.new()}
  end

  def frame(stream, identifier, payload) do
    key = {stream, identifier, payload}

    case :ets.lookup(__MODULE__, key) do
      [{^key, frame}] -> {:ok, frame}
      _ -> GenServer.call(__MODULE__, {:frame, key})
    end
  end

  def handle_call({:frame, {_, identifier, payload} = key}, _, queue) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, frame}] ->
        {:reply, {:ok, frame}, queue}

      _ ->
        case Jason.decode(payload) do
          {:ok, data} ->
            frame = Campfire.Rails.json(%{"identifier" => identifier, "message" => data})

            queue =
              if byte_size(payload) <= 262_144 do
                queue =
                  if :ets.info(__MODULE__, :size) >= @capacity do
                    {{:value, oldest}, rest} = :queue.out(queue)
                    :ets.delete(__MODULE__, oldest)
                    rest
                  else
                    queue
                  end

                :ets.insert(__MODULE__, {key, frame})
                :queue.in(key, queue)
              else
                queue
              end

            {:reply, {:ok, frame}, queue}

          error ->
            {:reply, error, queue}
        end
    end
  end
end
