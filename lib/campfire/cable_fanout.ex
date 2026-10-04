defmodule Campfire.CableFanout do
  @moduledoc """
  In-process Action Cable fan-out.

  Connections register `{stream, identifier}` in `Campfire.Streams`. A set of
  broadcasts is encoded once per stream and identifier, grouped per connection
  in order, and sent as one message per connection, so a connection writes
  everything addressed to it by one action (for example a message and its
  unread-room notice) with a single socket write. Frames are shared binaries.
  """
  alias Campfire.Rails

  @spec deliver([{stream :: String.t(), data :: term()}]) :: :ok
  def deliver(broadcasts) do
    broadcasts
    |> Enum.reduce(%{}, &collect/2)
    |> Enum.each(fn {pid, frames} -> send(pid, {:cable_frames, Enum.reverse(frames)}) end)
  end

  # Frames accumulate per connection in reverse order.
  defp collect({stream, data}, outbox) do
    {outbox, _} =
      Enum.reduce(Registry.lookup(Campfire.Streams, stream), {outbox, %{}}, fn
        {pid, identifier}, {outbox, frames} ->
          {frame, frames} =
            case frames do
              %{^identifier => frame} ->
                {frame, frames}

              _ ->
                frame = Rails.json(%{"identifier" => identifier, "message" => data})
                {frame, Map.put(frames, identifier, frame)}
            end

          {Map.update(outbox, pid, [frame], &[frame | &1]), frames}
      end)

    outbox
  end
end
