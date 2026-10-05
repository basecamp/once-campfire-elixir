defmodule Campfire.CableRedisBridge do
  use GenServer

  alias Campfire.Cable

  @prefix "campfire_production:"
  @internal_prefix "action_cable/"

  def start_link(url), do: GenServer.start_link(__MODULE__, url, name: __MODULE__)

  def publish(stream, payload) do
    Redix.command(Campfire.Redis, ["PUBLISH", @prefix <> stream, payload])
    :ok
  end

  @impl true
  def init(url) do
    {:ok, pubsub} = Redix.PubSub.start_link(url)
    {:ok, reference} = Redix.PubSub.psubscribe(pubsub, @prefix <> "*", self())

    receive do
      {:redix_pubsub, ^pubsub, ^reference, :psubscribed, _} ->
        {:ok, %{pubsub: pubsub, reference: reference}}
    after
      5_000 ->
        {:stop, :subscription_timeout}
    end
  end

  @impl true
  def handle_info(
        {:redix_pubsub, pubsub, reference, :pmessage,
         %{channel: @prefix <> stream, payload: payload}},
        %{pubsub: pubsub, reference: reference} = state
      ) do
    deliver(stream, payload)
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  def deliver(@internal_prefix <> encoded_user, payload) do
    with {:ok, "gid://campfire/User/" <> id} <-
           Base.url_decode64(encoded_user, padding: false),
         {user_id, ""} <- Integer.parse(id),
         {:ok, %{"type" => "disconnect"} = message} <- Jason.decode(payload) do
      reconnect = Map.get(message, "reconnect", true)

      Registry.dispatch(Campfire.Connections, user_id, fn entries ->
        for {pid, _} <- entries, do: send(pid, {:disconnect, reconnect})
      end)
    else
      _ -> :ok
    end
  end

  def deliver(stream, payload) do
    Cable.deliver(stream, payload)
  end
end
