defmodule Campfire.CableFanoutTest do
  use ExUnit.Case, async: false
  alias Campfire.Cable

  test "broadcasts encode one frame per stream and identifier, shared across connections" do
    test = self()

    connections =
      for _ <- 1..2 do
        spawn_link(fn ->
          Registry.register(Campfire.Streams, "room-stream", "subscription-id")
          send(test, :registered)

          receive do
            {:cable_frames, frames} -> send(test, {:frames, frames})
          end
        end)
      end

    for _ <- connections, do: assert_receive(:registered)
    assert :ok = Cable.broadcast("room-stream", %{"body" => "hello"})

    assert_receive {:frames, [frame]}
    assert_receive {:frames, [^frame]}

    assert Jason.decode!(frame) == %{
             "identifier" => "subscription-id",
             "message" => %{"body" => "hello"}
           }
  end

  test "grouped broadcasts reach each connection together and in order" do
    Registry.register(Campfire.Streams, "messages-stream", "messages-id")
    Registry.register(Campfire.Streams, "unreads-stream", "unreads-id")

    assert :ok =
             Cable.broadcast_all([
               {"messages-stream", "<turbo-stream></turbo-stream>"},
               {"unreads-stream", %{"roomId" => 1}},
               {"nobody-stream", %{"ignored" => true}}
             ])

    assert_receive {:cable_frames, [message, unread]}
    assert Jason.decode!(message)["identifier"] == "messages-id"
    assert Jason.decode!(unread) == %{"identifier" => "unreads-id", "message" => %{"roomId" => 1}}

    assert {:push, [{:text, ^message}, {:text, ^unread}], %{}} =
             Cable.handle_info({:cable_frames, [message, unread]}, %{})
  end

  test "disconnects reach the user's local connections" do
    Registry.register(Campfire.Connections, 42, nil)
    Cable.disconnect(42, false)
    assert_receive {:disconnect, false}
  end
end
