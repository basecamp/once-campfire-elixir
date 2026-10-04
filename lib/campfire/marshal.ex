defmodule Campfire.Marshal do
  import Bitwise

  def dump(value) do
    {bytes, _} = value(value, %{symbols: [], objects: 0, floats: %{}})
    <<4, 8>> <> IO.iodata_to_binary(bytes)
  end

  defp value(nil, symbols), do: {"0", symbols}
  defp value(true, symbols), do: {"T", symbols}
  defp value(false, symbols), do: {"F", symbols}
  defp value(%{"sym" => name}, symbols), do: symbol(name, symbols)

  defp value(%{"str" => text}, symbols) do
    symbols = %{symbols | objects: symbols.objects + 1}
    {encoding, symbols} = symbol("E", symbols)
    {["I\"", long(byte_size(text)), text, long(1), encoding, "T"], symbols}
  end

  defp value(%{"hash" => entries}, symbols) do
    symbols = %{symbols | objects: symbols.objects + 1}

    {pairs, symbols} =
      Enum.map_reduce(entries, symbols, fn [key, item], symbols ->
        {key, symbols} = symbol(key, symbols)
        {item, symbols} = value(item, symbols)
        {[key, item], symbols}
      end)

    {["{", long(length(entries)), pairs], symbols}
  end

  defp value(items, symbols) when is_list(items) do
    symbols = %{symbols | objects: symbols.objects + 1}
    {items, symbols} = Enum.map_reduce(items, symbols, &value/2)
    {["[", long(length(items)), items], symbols}
  end

  defp value(n, symbols) when is_integer(n) do
    bytes =
      if n >= -1_073_741_824 && n < 1_073_741_824 do
        ["i", long(n)]
      else
        bytes = :binary.encode_unsigned(abs(n), :little)
        bytes = if rem(byte_size(bytes), 2) == 1, do: bytes <> <<0>>, else: bytes
        ["l", if(n < 0, do: "-", else: "+"), long(div(byte_size(bytes), 2)), bytes]
      end

    symbols =
      if n < -1_073_741_824 || n >= 1_073_741_824,
        do: %{symbols | objects: symbols.objects + 1},
        else: symbols

    {bytes, symbols}
  end

  defp value(n, state) when is_float(n) do
    key = <<n::float-64>>
    <<bits::64>> = key
    exponent = band(bits >>> 52, 2047)
    immediate = bits == 0 || exponent in 768..1279

    case if(immediate, do: Map.fetch(state.floats, key), else: :error) do
      {:ok, index} ->
        {["@", long(index)], state}

      :error ->
        text = float_text(n)
        floats = if immediate, do: Map.put(state.floats, key, state.objects), else: state.floats
        state = %{state | objects: state.objects + 1, floats: floats}
        {["f", long(byte_size(text)), text], state}
    end
  end

  defp float_text(n) do
    text = :erlang.float_to_binary(n, [:short])

    {sign, text} =
      if String.starts_with?(text, "-"),
        do: {"-", String.trim_leading(text, "-")},
        else: {"", text}

    [mantissa | exponent] = String.split(text, "e")
    exponent = if exponent == [], do: 0, else: String.to_integer(hd(exponent))
    [whole | fraction] = String.split(mantissa, ".")
    digits = whole <> Enum.join(fraction)
    leading = byte_size(digits) - byte_size(String.trim_leading(digits, "0"))
    point = byte_size(whole) + exponent - leading
    digits = digits |> String.trim_leading("0") |> String.trim_trailing("0")

    cond do
      digits == "" ->
        sign <> "0"

      point > byte_size(digits) || point < -3 ->
        fraction = String.slice(digits, 1..-1//1)

        sign <>
          String.first(digits) <>
          if(fraction == "", do: "", else: "." <> fraction) <> "e" <> to_string(point - 1)

      point <= 0 ->
        sign <> "0." <> String.duplicate("0", -point) <> digits

      point == byte_size(digits) ->
        sign <> digits

      true ->
        sign <>
          binary_part(digits, 0, point) <>
          "." <> binary_part(digits, point, byte_size(digits) - point)
    end
  end

  defp symbol(name, symbols) do
    case Enum.find_index(symbols.symbols, &(&1 == name)) do
      nil -> {[":", long(byte_size(name)), name], %{symbols | symbols: symbols.symbols ++ [name]}}
      index -> {[";", long(index)], symbols}
    end
  end

  defp long(0), do: <<0>>
  defp long(n) when n > 0 and n < 123, do: <<n + 5>>
  defp long(n) when n < 0 and n > -124, do: <<band(n - 5, 255)>>

  defp long(n) do
    bytes = digits(n, [])
    count = if n < 0, do: -length(bytes), else: length(bytes)
    [<<band(count, 255)>>, bytes]
  end

  defp digits(n, acc) do
    byte = band(n, 255)
    rest = n >>> 8
    acc = acc ++ [byte]
    if rest in [0, -1], do: acc, else: digits(rest, acc)
  end
end
