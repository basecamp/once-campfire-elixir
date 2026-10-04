defmodule Campfire.Clock do
  def now do
    case System.get_env("CAMPFIRE_CLOCK") do
      nil ->
        DateTime.utc_now()

      value ->
        {:ok, now, _} = DateTime.from_iso8601(value)

        if System.get_env("CAMPFIRE_CLOCK_TICK") == "1" do
          key = {__MODULE__, value, :started}

          started =
            case :persistent_term.get(key, nil) do
              nil ->
                time = System.monotonic_time(:microsecond)
                :persistent_term.put(key, time)
                time

              time ->
                time
            end

          DateTime.add(now, System.monotonic_time(:microsecond) - started, :microsecond)
        else
          now
        end
    end
  end
end
