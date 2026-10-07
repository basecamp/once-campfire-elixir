defmodule Campfire.Rack do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Rack's inclusive byte-range behavior, including Ruby integer conversion quirks."
  def integer(text) do
    case Regex.run(~r/^[\x09-\x0d\x20]*([+-]?)(?:0[dD])?([0-9](?:_?[0-9])*)/, text) do
      [_, sign, digits] ->
        String.to_integer(String.replace(digits, "_", "")) * if(sign == "-", do: -1, else: 1)

      _ ->
        0
    end
  end

  def ranges(nil, _), do: nil
  def ranges(_, 0), do: nil

  def ranges(header, size) do
    with [_, spec] <- Regex.run(~r/bytes=([^;]+)/, header),
         true <- length(String.split(spec, ",")) <= 100 do
      result =
        Regex.split(~r/,[ \t]*/, spec)
        |> drop_trailing()
        |> Enum.reduce_while([], fn spec, acc ->
          case range(spec, size) do
            :invalid -> {:halt, nil}
            :unsatisfiable -> {:cont, acc}
            [a, b] -> {:cont, acc ++ [[a, b]]}
          end
        end)

      cond do
        is_nil(result) -> nil
        Enum.reduce(result, 0, fn [a, b], sum -> sum + b - a + 1 end) > size -> []
        true -> result
      end
    else
      _ -> nil
    end
  end

  defp range(spec, size) do
    if String.contains?(spec, "-") do
      parts = String.split(spec, "-") |> drop_trailing()

      case parts do
        ["", suffix | _] ->
          valid(max(size - integer(suffix), 0), size - 1)

        [] ->
          :invalid

        [""] ->
          :invalid

        [first] ->
          valid(integer(first), size - 1)

        [first, last | _] ->
          a = integer(first)
          b = integer(last)
          if b < a, do: :invalid, else: valid(a, min(b, size - 1))
      end
    else
      :invalid
    end
  end

  defp valid(a, b), do: if(a <= b, do: [a, b], else: :unsatisfiable)

  defp drop_trailing(parts),
    do: parts |> Enum.reverse() |> Enum.drop_while(&(&1 == "")) |> Enum.reverse()
end
