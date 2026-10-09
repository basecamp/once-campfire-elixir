defmodule Campfire.Escape do
  @moduledoc """
  Single-pass HTML escaping.

  Each function returns exactly what its former chain of `String.replace/3`
  calls returned (escaping `&` first is what keeps the chain from escaping
  its own entities), including for invalid UTF-8, where `"\\u00a0"` matches
  its two bytes at any offset. Text without anything to escape is returned
  as is. Non-binaries go through the original chain so they raise the same
  errors.
  """

  @text [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {" ", "&nbsp;"}]
  @attr @text ++ [{"\"", "&quot;"}]
  @html [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {"\"", "&quot;"}, {"'", "&#39;"}]

  @doc "`&`, `<`, `>` and non-breaking spaces, as Action Text serializes text."
  def text(value), do: escape_text(value, value, 0, 0, [])

  @doc "`text/1` plus double quotes, for attribute values."
  def attr(value), do: escape_attr(value, value, 0, 0, [])

  @doc "`&`, `<`, `>`, `\"` and `'`, as ERB's `h`."
  def html(value), do: escape_html(value, value, 0, 0, [])

  for {name, escapes} <- [escape_text: @text, escape_attr: @attr, escape_html: @html] do
    for {match, replacement} <- escapes do
      size = byte_size(match)

      defp unquote(name)(<<unquote(match), rest::binary>>, original, skip, length, acc) do
        acc = [acc, binary_part(original, skip, length) | unquote(replacement)]
        unquote(name)(rest, original, skip + length + unquote(size), 0, acc)
      end
    end

    defp unquote(name)(<<_, rest::binary>>, original, skip, length, acc),
      do: unquote(name)(rest, original, skip, length + 1, acc)

    defp unquote(name)(<<>>, original, _skip, _length, []), do: original

    defp unquote(name)(<<>>, original, skip, length, acc),
      do: IO.iodata_to_binary([acc | binary_part(original, skip, length)])

    defp unquote(name)(value, _original, _skip, _length, _acc),
      do: Enum.reduce(unquote(escapes), value, fn {m, r}, v -> String.replace(v, m, r) end)
  end
end
