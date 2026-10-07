defmodule Campfire.Filename do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @approximations Jason.decode!(File.read!("priv/transliterations.json"))
  def sanitized(raw) do
    raw
    |> utf8()
    |> String.replace(~r/^[\x00\x09-\x0d\x20]+|[\x00\x09-\x0d\x20]+$/, "")
    |> String.replace(~r/[\x{202e}%$|:;\/<>?*"\t\r\n\\]/u, "-")
  end

  defp utf8(raw) do
    case :unicode.characters_to_binary(raw) do
      text when is_binary(text) -> text
      {:error, good, <<_, rest::binary>>} -> good <> "�" <> utf8(rest)
      {:incomplete, good, _} -> good <> "�"
    end
  end

  def basename(raw) do
    trimmed = String.trim_trailing(raw, "/")

    if trimmed == "",
      do: if(raw == "", do: "", else: "/"),
      else: List.last(String.split(trimmed, "/"))
  end

  def extension(raw) do
    name = raw |> basename() |> String.trim_leading(".")

    case :binary.matches(name, ".") do
      [] ->
        ""

      matches ->
        {index, _} = List.last(matches)
        binary_part(name, index + 1, byte_size(name) - index - 1)
    end
  end

  def base(raw) do
    name = basename(raw)
    extension = extension(raw)

    if extension != "" || (String.ends_with?(name, ".") && String.trim(name, ".") != "") do
      binary_part(name, 0, byte_size(name) - byte_size(extension) - 1)
    else
      name
    end
  end

  def disposition(kind, raw) do
    filename = sanitized(raw)

    ascii =
      filename
      |> String.to_charlist()
      |> Enum.map_join(fn char ->
        if char < 128, do: <<char>>, else: Map.get(@approximations, <<char::utf8>>, "?")
      end)

    kind <>
      "; filename=\"" <>
      escape(ascii, " !#$+.^_`|~-") <> "\"; filename*=UTF-8''" <> escape(filename, "!#$&+.^_`|~-")
  end

  def escape_path(raw), do: escape(raw, "-._~!$&'()*+,;=:@/")
  def escape_segment(raw), do: escape(raw, "-._~!$&'()*+,;=:@")

  defp escape(raw, allowed) do
    for <<byte <- raw>>, into: "" do
      if byte in ?a..?z || byte in ?A..?Z || byte in ?0..?9 ||
           :binary.match(allowed, <<byte>>) != :nomatch,
         do: <<byte>>,
         else:
           "%" <> (Integer.to_string(byte, 16) |> String.upcase() |> String.pad_leading(2, "0"))
    end
  end
end
