defmodule Campfire.CableFanoutTest do
  use ExUnit.Case, async: true
  alias Campfire.{CableFanout, Rails}

  defp stream, do: "fanout-test-#{System.unique_integer([:positive])}"

  defp subscriber(registrations) do
    parent = self()

    pid =
      spawn_link(fn ->
        for {stream, identifier} <- registrations,
            do: Registry.register(Campfire.Streams, stream, identifier)

        send(parent, :registered)
        receive do: ({:cable_frames, frames} -> send(parent, {:frames, self(), frames}))
      end)

    assert_receive :registered
    pid
  end

  test "frames are encoded per identifier and grouped per connection in order" do
    {messages, unreads} = {stream(), stream()}
    data = %{"html" => "<turbo-stream action=\"append\"><p>&amp; café</p></turbo-stream>"}
    both = subscriber([{messages, "one"}, {unreads, "unread"}])
    other = subscriber([{messages, "two"}])

    CableFanout.deliver([{messages, data}, {unreads, %{"roomId" => 1}}])

    assert_receive {:frames, ^both, frames}

    assert frames == [
             Rails.json(%{"identifier" => "one", "message" => data}),
             Rails.json(%{"identifier" => "unread", "message" => %{"roomId" => 1}})
           ]

    assert_receive {:frames, ^other, [frame]}
    assert frame == Rails.json(%{"identifier" => "two", "message" => data})
  end

  test "streams without local subscribers are ignored" do
    assert CableFanout.deliver([{stream(), %{"x" => 1}}]) == :ok
  end
end
