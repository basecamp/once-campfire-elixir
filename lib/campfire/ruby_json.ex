defmodule Campfire.RubyJSON do
  @moduledoc "The comments accepted by Ruby JSON, without touching comment markers inside strings."
  def decode(json), do: json |> strip(false, false, []) |> IO.iodata_to_binary() |> Jason.decode()

  defp strip(<<>>, _, _, acc), do: Enum.reverse(acc)

  defp strip(<<character, rest::binary>>, true, escaped, acc) do
    cond do
      escaped -> strip(rest, true, false, [<<character>> | acc])
      character == ?\\ -> strip(rest, true, true, [<<character>> | acc])
      character == ?" -> strip(rest, false, false, [<<character>> | acc])
      true -> strip(rest, true, false, [<<character>> | acc])
    end
  end

  defp strip(<<"/*", rest::binary>>, false, _, acc) do
    case :binary.split(rest, "*/") do
      [_, remaining] -> strip(remaining, false, false, [" " | acc])
      [_] -> Enum.reverse(["/*" <> rest | acc])
    end
  end

  defp strip(<<"//", rest::binary>>, false, _, acc) do
    case :binary.split(rest, "\n") do
      [_, remaining] -> strip(remaining, false, false, ["\n" | acc])
      [_] -> Enum.reverse(acc)
    end
  end

  defp strip(<<character, rest::binary>>, false, _, acc),
    do: strip(rest, character == ?", false, [<<character>> | acc])
end
