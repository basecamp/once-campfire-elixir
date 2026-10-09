defmodule Campfire.Cable do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @behaviour WebSock
  import Plug.Conn
  alias Campfire.{Auth, CableFanout, Chat, Clock, Presence, Rails}

  def upgrade(conn) do
    {conn, user, _session} = Auth.session_lookup(conn)
    origin = List.first(get_req_header(conn, "origin"))

    requested =
      get_req_header(conn, "sec-websocket-protocol")
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.map(&String.trim/1)

    if origin != Auth.base(conn) || "actioncable-v1-json" not in requested do
      conn |> put_resp_content_type("text/html") |> send_resp(404, "")
    else
      conn
      |> put_resp_header("sec-websocket-protocol", "actioncable-v1-json")
      |> upgrade_adapter(
        :websocket,
        {__MODULE__, %{user: user, subscriptions: %{}}, websocket_options()}
      )
      |> halt()
    end
  end

  @doc false
  def websocket_options, do: [compress: false, timeout: :infinity]

  @impl true
  def init(%{user: nil} = state),
    do:
      {:stop, :normal, 1000,
       [
         {:text,
          Rails.json(%{"type" => "disconnect", "reason" => "unauthorized", "reconnect" => false})}
       ], state}

  def init(state) do
    Registry.register(Campfire.Connections, state.user["id"], nil)
    Process.send_after(self(), :ping, 3000)
    {:push, {:text, Rails.json(%{"type" => "welcome"})}, state}
  end

  @impl true
  def handle_in({raw, [opcode: :text]}, state) do
    case Jason.decode(raw) do
      {:ok, %{"command" => "subscribe", "identifier" => id}} when is_binary(id) ->
        subscribe(id, state)

      {:ok, %{"command" => "unsubscribe", "identifier" => id}} ->
        {:ok, unsubscribe(id, state)}

      {:ok, %{"command" => "message", "identifier" => id, "data" => data}} ->
        perform(id, data, state)

      _ ->
        {:ok, state}
    end
  end

  def handle_in(_, state), do: {:ok, state}

  defp subscribe(id, state) do
    if Map.has_key?(state.subscriptions, id) do
      {:push, {:text, Rails.json(%{"identifier" => id, "type" => "confirm_subscription"})}, state}
    else
      with {:ok, params} <- Jason.decode(id),
           {:ok, sub} <- authorize(params, state.user) do
        if sub.stream, do: register(sub.stream, id)

        if sub.channel == "PresenceChannel" do
          Presence.present(state.user, sub.room)
          broadcast("user_#{state.user["id"]}_reads", %{"room_id" => sub.room["id"]})
        end

        state = put_in(state.subscriptions[id], sub)

        {:push, {:text, Rails.json(%{"identifier" => id, "type" => "confirm_subscription"})},
         state}
      else
        _ ->
          {:push, {:text, Rails.json(%{"identifier" => id, "type" => "reject_subscription"})},
           state}
      end
    end
  end

  defp authorize(%{"channel" => channel} = params, user) do
    case channel do
      "HeartbeatChannel" ->
        {:ok, %{channel: channel, stream: nil, room: nil}}

      "ReadRoomsChannel" ->
        {:ok, %{channel: channel, stream: "user_#{user["id"]}_reads", room: nil}}

      "UnreadRoomsChannel" ->
        {:ok, %{channel: channel, stream: "user_#{user["id"]}_unreads", room: nil}}

      channel when channel in ["RoomChannel", "PresenceChannel", "TypingNotificationsChannel"] ->
        if room = Chat.room(user, params["room_id"]) do
          name = channel |> String.replace("Channel", "") |> Macro.underscore()
          {:ok, %{channel: channel, stream: name <> ":" <> gid_param(room), room: room}}
        else
          :reject
        end

      "RoomMessagesChannel" ->
        with stream when is_binary(stream) <-
               Rails.verify_stream(params["signed_stream_name"] || ""),
             [gid, "messages"] <- String.split(stream, ":", parts: 2),
             {:ok, plain} <- Base.url_decode64(gid, padding: false),
             [_, type, id] <-
               Regex.run(
                 ~r/\Agid:\/\/campfire\/(Rooms::(?:Open|Closed|Direct)|Room)\/([0-9]+)\z/,
                 plain
               ),
             room when is_map(room) <- Chat.room(user, id),
             true <- type == "Room" || type == room["type"] do
          {:ok, %{channel: channel, stream: stream, room: room}}
        else
          _ -> :reject
        end

      "Turbo::StreamsChannel" ->
        with stream when is_binary(stream) <-
               Rails.verify_stream(params["signed_stream_name"] || ""),
             false <- match?([_, "messages"], String.split(stream, ":", parts: 2)) do
          {:ok, %{channel: channel, stream: stream, room: nil}}
        else
          _ -> :reject
        end

      _ ->
        :reject
    end
  end

  defp authorize(_, _), do: :reject

  defp register(stream, id) do
    Registry.register(Campfire.Streams, stream, id)
  end

  defp unsubscribe(id, state) do
    case Map.pop(state.subscriptions, id) do
      {nil, _} ->
        state

      {sub, subscriptions} ->
        if sub.channel == "PresenceChannel", do: Presence.absent(state.user, sub.room)

        if sub.stream do
          Registry.unregister_match(Campfire.Streams, sub.stream, id)
        end

        %{state | subscriptions: subscriptions}
    end
  end

  defp perform(id, data, state) do
    with sub when is_map(sub) <- state.subscriptions[id],
         {:ok, params} <- Jason.decode(data),
         %{"action" => action} <- params do
      cond do
        sub.channel == "PresenceChannel" && action == "refresh" ->
          Presence.refresh(state.user, sub.room)

        sub.channel == "TypingNotificationsChannel" && action in ["start", "stop"] ->
          broadcast(sub.stream, %{
            "action" => action,
            "user" => Map.take(state.user, ["id", "name"])
          })

        true ->
          :ok
      end
    end

    {:ok, state}
  end

  def broadcast(stream, data), do: broadcast_all([{stream, data}])

  @doc "Delivers several broadcasts together, in order."
  def broadcast_all(broadcasts), do: CableFanout.deliver(broadcasts)

  def disconnect(user_id, reconnect) do
    Registry.dispatch(Campfire.Connections, user_id, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:disconnect, reconnect})
    end)
  end

  def gid_param(room),
    do: Base.url_encode64("gid://campfire/#{room["type"]}/#{room["id"]}", padding: false)

  def messages_stream(room), do: gid_param(room) <> ":messages"

  @impl true
  def handle_info(:ping, state) do
    Process.send_after(self(), :ping, 3000)

    {:push, {:text, Rails.json(%{"type" => "ping", "message" => DateTime.to_unix(Clock.now())})},
     state}
  end

  # Frames are encoded once per stream and identifier by `Campfire.CableFanout`.
  def handle_info({:cable_frames, frames}, state),
    do: {:push, Enum.map(frames, &{:text, &1}), state}

  def handle_info({:disconnect, reconnect}, state),
    do:
      {:stop, :normal, 1000,
       [
         {:text,
          Rails.json(%{"type" => "disconnect", "reason" => "remote", "reconnect" => reconnect})}
       ], state}

  def handle_info(_, state), do: {:ok, state}

  @impl true
  def terminate(_, state) do
    for {id, _} <- state.subscriptions, do: unsubscribe(id, state)
    :ok
  end
end
