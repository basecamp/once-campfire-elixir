defmodule Campfire.CookieCodec do
  @moduledoc """
  Percent encoding for cookie values, byte-identical to `URI.encode/2` with
  `&URI.char_unreserved?/1` and `URI.decode/1`, without a predicate call per byte.

  Values we sign are base64 plus the `--` separator, so only `+`, `/` and `=` ever need escaping
  and the hot path can splice around those three bytes instead of walking every byte. Anything
  else falls back to a single pass over the escape table. Decoding walks `%` positions only.
  """

  @unreserved (for byte <- 0..255 do
                 byte in ?A..?Z or byte in ?a..?z or byte in ?0..?9 or byte in [?-, ?., ?_, ?~]
               end)
              |> List.to_tuple()

  @escapes (for byte <- 0..255 do
              if elem(@unreserved, byte), do: nil, else: "%" <> Base.encode16(<<byte>>)
            end)
           |> List.to_tuple()

  @cookie_shape ~r/\A[A-Za-z0-9+\/=\-_]+\z/
  @cookie_escapes ["+", "/", "="]

  def encode(binary) do
    if Regex.match?(@cookie_shape, binary),
      do: encode_escapes(binary, []),
      else: encode_bytes(binary, [])
  end

  def decode(binary), do: decode_escapes(binary, [])

  defp encode_escapes(binary, acc) do
    case :binary.match(binary, @cookie_escapes) do
      :nomatch ->
        IO.iodata_to_binary(:lists.reverse([binary | acc]))

      {position, 1} ->
        prefix = binary_part(binary, 0, position)
        escaped = elem(@escapes, :binary.at(binary, position))
        rest = binary_part(binary, position + 1, byte_size(binary) - position - 1)
        encode_escapes(rest, [escaped, prefix | acc])
    end
  end

  defp encode_bytes(<<>>, acc), do: IO.iodata_to_binary(:lists.reverse(acc))

  defp encode_bytes(<<byte, rest::binary>>, acc) do
    case elem(@escapes, byte) do
      nil -> encode_bytes(rest, [byte | acc])
      escaped -> encode_bytes(rest, [escaped | acc])
    end
  end

  # URI.decode/1 leaves a % that is not followed by two hex digits as it is; so do we.
  defp decode_escapes(binary, acc) do
    case :binary.match(binary, "%") do
      :nomatch ->
        IO.iodata_to_binary(:lists.reverse([binary | acc]))

      {position, 1} ->
        prefix = binary_part(binary, 0, position)
        rest = binary_part(binary, position, byte_size(binary) - position)
        decode_at(rest, prefix, acc)
    end
  end

  defp decode_at(<<?%, high, low, tail::binary>>, prefix, acc) do
    case Base.decode16(<<high, low>>, case: :mixed) do
      {:ok, byte} -> decode_escapes(tail, [byte, prefix | acc])
      :error -> decode_escapes(<<high, low, tail::binary>>, [?%, prefix | acc])
    end
  end

  defp decode_at(<<?%, tail::binary>>, prefix, acc), do: decode_escapes(tail, [?%, prefix | acc])
end
