defmodule Campfire.RateLimiter do
  use GenServer
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(state), do: {:ok, state}
  def clear, do: GenServer.call(__MODULE__, :clear)

  def allowed?(key, limit, seconds) do
    GenServer.call(__MODULE__, {:hit, key, limit, seconds})
  end

  def handle_call(:clear, _, _), do: {:reply, :ok, %{}}

  def handle_call({:hit, key, limit, seconds}, _, state) do
    now = System.monotonic_time(:second)
    state = Map.filter(state, fn {_, {expiry, _}} -> expiry > now end)
    {expiry, count} = Map.get(state, key, {now + seconds, 0})
    count = count + 1
    {:reply, count <= limit, Map.put(state, key, {expiry, count})}
  end
end
