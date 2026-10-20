defmodule Campfire.Clock do
  @moduledoc """
  The reference clock, pinned by `CAMPFIRE_CLOCK` when parity runs need a fixed instant.
  """
  def now do
    case config() do
      nil ->
        DateTime.utc_now()

      {value, tick?} ->
        {:ok, now, _} = DateTime.from_iso8601(value)

        if tick? do
          DateTime.add(now, System.monotonic_time(:microsecond) - started(value), :microsecond)
        else
          now
        end
    end
  end

  defp config do
    case Campfire.Env.get("CAMPFIRE_CLOCK") do
      nil -> nil
      clock -> {clock, Campfire.Env.get("CAMPFIRE_CLOCK_TICK") == "1"}
    end
  end

  defp started(value) do
    Campfire.Memo.fetch({:clock_started, value}, fn -> System.monotonic_time(:microsecond) end)
  end
end
