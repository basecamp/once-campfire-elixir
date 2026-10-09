defmodule Campfire.Clock do
  @moduledoc """
  The current time, or a fixed one for parity runs and tests.

  `CAMPFIRE_CLOCK` (with `CAMPFIRE_CLOCK_TICK=1` to let it advance) is read
  once at startup; tests change it with `set/2`.
  """
  @key {__MODULE__, :fixed}

  def configure,
    do: set(System.get_env("CAMPFIRE_CLOCK"), System.get_env("CAMPFIRE_CLOCK_TICK") == "1")

  def set(value, tick \\ false)
  def set(nil, _tick), do: :persistent_term.put(@key, nil)

  def set(value, tick) do
    {:ok, time, _} = DateTime.from_iso8601(value)
    :persistent_term.put(@key, {time, tick && System.monotonic_time(:microsecond)})
  end

  def fixed?, do: :persistent_term.get(@key, nil) != nil

  def now do
    case :persistent_term.get(@key, nil) do
      nil ->
        DateTime.utc_now()

      {time, false} ->
        time

      {time, started} ->
        DateTime.add(time, System.monotonic_time(:microsecond) - started, :microsecond)
    end
  end
end
