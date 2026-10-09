defmodule Campfire.JSON do
  @moduledoc """
  Rails' JSON as an encoder for OTP's `:json`.

  Strings are escaped like `json:encode_binary/1` and, as Rails does, `<`, `>`
  and `&` become unicode escapes, all in the same single pass (Rails 8.1 no
  longer escapes U+2028/U+2029, so neither does this). `nil` is `null` and
  dates and times are ISO 8601 strings.

  Objects whose key order matters, as in Rails' hashes, are lists of
  `{key, value}` pairs; `decode/1` returns objects that way so stored JSON
  keeps its order when rewritten. Maps have no order.

  The string and map encoding are ported from OTP's `json.erl`
  (Copyright Ericsson AB 2024-2025, Apache-2.0), including its SWAR ASCII
  fast path and its UTF-8 validation, which raises the same errors.
  """
  import Bitwise

  @decoders %{
    null: nil,
    object_start: &__MODULE__.object_start/1,
    object_push: &__MODULE__.object_push/3,
    object_finish: &__MODULE__.object_finish/2
  }

  @doc false
  def object_start(_parent), do: []
  @doc false
  def object_push(key, value, pairs), do: [{key, value} | pairs]
  @doc false
  def object_finish([], parent), do: {%{}, parent}
  def object_finish(pairs, parent), do: {:lists.reverse(pairs), parent}

  def encode(value), do: :json.encode(value, &encode/2)

  @doc false
  def encode(nil, _encode), do: "null"
  def encode(string, _encode) when is_binary(string), do: escape(string)
  def encode(%DateTime{} = value, _encode), do: escape(DateTime.to_iso8601(value))
  def encode(%NaiveDateTime{} = value, _encode), do: escape(NaiveDateTime.to_iso8601(value))
  def encode(%Date{} = value, _encode), do: escape(Date.to_iso8601(value))
  def encode(%Time{} = value, _encode), do: escape(Time.to_iso8601(value))

  def encode(%_{} = struct, _encode),
    do: raise(ArgumentError, "cannot encode #{inspect(struct)} as JSON")

  def encode(map, encode) when is_map(map),
    do: object(for({key, value} <- map, do: [?,, key(key, encode), ?: | encode.(value, encode)]))

  def encode([{_, _} | _] = pairs, encode),
    do:
      object(for({key, value} <- pairs, do: [?,, key(key, encode), ?: | encode.(value, encode)]))

  def encode(value, encode), do: :json.encode_value(value, encode)

  defp object([]), do: "{}"
  defp object([[_comma | entry] | rest]), do: [?{, entry, rest, ?}]

  @doc """
  Decodes JSON, with `nil` for null and non-empty objects as lists of
  `{key, value}` pairs in their original order (empty objects are `%{}`).
  """
  def decode(binary) do
    {:ok, decode!(binary)}
  rescue
    error -> {:error, error}
  end

  @doc "The pairs of a decoded object (`%{}` when empty)."
  def pairs(object) when object == %{}, do: []
  def pairs(object) when is_list(object), do: object

  def decode!(binary) do
    case :json.decode(binary, :ok, @decoders) do
      {value, :ok, rest} ->
        if String.trim_leading(rest, " \t\n\r") == "",
          do: value,
          else: raise(ArgumentError, "unexpected data after JSON value")
    end
  end

  defp key(key, encode) when is_binary(key), do: encode.(key, encode)
  defp key(key, encode) when is_atom(key), do: encode.(Atom.to_string(key), encode)
  defp key(key, _encode) when is_integer(key), do: [?", Integer.to_string(key), ?"]
  defp key(key, _encode) when is_float(key), do: [?", :json.encode_float(key), ?"]

  ## String escaping, from json:escape_binary/1

  @utf8_accept 0
  @utf8_reject 12

  # Rails escapes these in addition to JSON's quote, backslash and control
  # characters.
  @html [?<, ?>, ?&]

  @mask80 0x80808080808080
  @mask01 0x01010101010101

  defguardp no_zero_byte(v) when band(v - @mask01, @mask80) == 0

  defguardp all_plain(w)
            when band(w, @mask80) == 0 and
                   band(w + 0x60606060606060, @mask80) == @mask80 and
                   no_zero_byte(bxor(w, 0x22222222222222)) and
                   no_zero_byte(bxor(w, 0x5C5C5C5C5C5C5C)) and
                   no_zero_byte(bxor(w, 0x3C3C3C3C3C3C3C)) and
                   no_zero_byte(bxor(w, 0x3E3E3E3E3E3E3E)) and
                   no_zero_byte(bxor(w, 0x26262626262626))

  defguardp plain(byte) when byte >= 32 and byte <= 127 and byte not in [?", ?\\ | @html]
  defguardp escaped(byte) when byte < 32 or byte in [?", ?\\ | @html]

  defp escape(string), do: escape_ascii(string, [?"], string, 0, 0)

  defp escape_ascii(<<w::56, rest::binary>>, acc, original, skip, length) when all_plain(w),
    do: escape_ascii(rest, acc, original, skip, length + 7)

  defp escape_ascii(binary, acc, original, skip, length),
    do: escape_binary(binary, acc, original, skip, length)

  defp escape_binary(<<byte, rest::binary>>, acc, original, skip, length) when plain(byte),
    do: escape_binary(rest, acc, original, skip, length + 1)

  defp escape_binary(<<byte, rest::binary>>, acc, original, skip, length) when escaped(byte) do
    escaped = escape_byte(byte)

    acc =
      if length == 0,
        do: [acc | escaped],
        else: [acc, binary_part(original, skip, length) | escaped]

    escape_ascii(rest, acc, original, skip + length + 1, 0)
  end

  defp escape_binary(<<byte, rest::binary>>, acc, original, skip, length) do
    case elem(utf8s0(), byte - 128) do
      @utf8_reject -> invalid_byte(original, skip + length)
      state -> escape_utf8(rest, acc, original, skip, length, state)
    end
  end

  defp escape_binary(_, _acc, original, 0, _length), do: [?", original, ?"]
  defp escape_binary(_, acc, _original, _skip, 0), do: [acc, ?"]

  defp escape_binary(_, acc, original, skip, length),
    do: [acc, binary_part(original, skip, length), ?"]

  defp escape_utf8(<<byte, rest::binary>>, acc, original, skip, length, state) do
    case elem(utf8s(), state + elem(utf8t(), byte) - 1) do
      @utf8_accept -> escape_ascii(rest, acc, original, skip, length + 2)
      @utf8_reject -> invalid_byte(original, skip + length + 1)
      state -> escape_utf8(rest, acc, original, skip, length + 1, state)
    end
  end

  defp escape_utf8(_, _acc, original, skip, length, _state),
    do: unexpected_utf8(original, skip + length + 1)

  for byte <- 0..31 do
    short = %{?\b => "\\b", ?\t => "\\t", ?\n => "\\n", ?\f => "\\f", ?\r => "\\r"}

    escaped =
      short[byte] ||
        "\\u" <> String.pad_leading(Integer.to_string(byte, 16), 4, "0")

    defp escape_byte(unquote(byte)), do: unquote(escaped)
  end

  defp escape_byte(?"), do: "\\\""
  defp escape_byte(?\\), do: "\\\\"
  defp escape_byte(?<), do: "\\u003c"
  defp escape_byte(?>), do: "\\u003e"
  defp escape_byte(?&), do: "\\u0026"

  defp invalid_byte(binary, skip), do: :erlang.error({:invalid_byte, :binary.at(binary, skip)})

  defp unexpected_utf8(original, skip) when byte_size(original) == skip,
    do: :erlang.error(:unexpected_end)

  defp unexpected_utf8(original, skip), do: invalid_byte(original, skip)

  # "Flexible and Economical UTF-8 Decoding" by Bjoern Hoehrmann, as adapted in
  # json.erl: character classes, state transitions, and the first byte's state.
  defp utf8t do
    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
     9, 9, 9, 9, 9, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
     7, 7, 7, 7, 7, 7, 8, 8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3, 11, 6, 6, 6, 5, 8, 8,
     8, 8, 8, 8, 8, 8, 8, 8, 8}
  end

  defp utf8s do
    {12, 24, 36, 60, 96, 84, 12, 12, 12, 48, 72, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
     12, 0, 12, 12, 12, 12, 12, 0, 12, 0, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 24, 12, 12,
     12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 12, 12, 24, 12,
     12, 12, 12, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12, 12, 36, 12, 12, 12, 12, 12, 36, 12, 36,
     12, 12, 12, 36, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12}
  end

  defp utf8s0 do
    {12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
     12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
     12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 24, 24, 24,
     24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
     24, 24, 24, 24, 48, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 60, 36, 36, 72, 84, 84,
     84, 96, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12}
  end
end
