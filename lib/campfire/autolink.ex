defmodule Campfire.Autolink do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  alias Campfire.Assets

  @urls ~r/(?:(?i:((?:ed2k|ftp|http|https|irc|mailto|news|gopher|nntp|telnet|webcal|xmpp|callto|feed|svn|urn|aim|rsync|tag|ssh|sftp|rtsp|afs|file):))\/\/|(?i:www)\.[a-zA-Z0-9_])[^\x09-\x0d <\x{A0}"]+/u
  @emails ~r/(?<![a-zA-Z0-9_.!#$%&'*\/=?^`{|}~+-])[a-zA-Z0-9_.!#$%+-]\.?[a-zA-Z0-9_.!#$%&'*\/=?^`{|}~+-]*@[a-zA-Z0-9_-]+(?:\.[a-zA-Z0-9_-]+)+/

  # Every URL match contains "://" or "www." (any case) and every email "@";
  # without them the scans cannot match.
  @www for a <- ~w(w W), b <- ~w(w W), c <- ~w(w W), do: a <> b <> c <> "."

  def render(html) do
    html =
      if :binary.match(html, url_marker()) != :nomatch,
        do: replace(html, @urls, &url/1),
        else: html

    if :binary.match(html, "@") != :nomatch, do: replace(html, @emails, &email/1), else: html
  end

  defp url_marker do
    case :persistent_term.get({__MODULE__, :url_marker}, nil) do
      nil ->
        pattern = :binary.compile_pattern(["://" | @www])
        :persistent_term.put({__MODULE__, :url_marker}, pattern)
        pattern

      pattern ->
        pattern
    end
  end

  defp replace(text, pattern, fun) do
    matches = Regex.scan(pattern, text, return: :index, capture: :first)

    {parts, offset} =
      Enum.map_reduce(matches, 0, fn [{start, length}], offset ->
        value = binary_part(text, start, length)
        left = binary_part(text, 0, start)
        right = binary_part(text, start + length, byte_size(text) - start - length)
        replacement = if linked?(left, right), do: value, else: fun.(value)
        {[binary_part(text, offset, start - offset), replacement], start + length}
      end)

    IO.iodata_to_binary([parts, binary_part(text, offset, byte_size(text) - offset)])
  end

  defp linked?(left, right) do
    tag = Regex.match?(~r/<[^>]+$/m, left) && Regex.match?(~r/^[^>]*>/, right)

    anchor =
      case Regex.scan(~r/<a\b.*?>/i, left, return: :index) |> List.last() do
        [{start, _}] ->
          !Regex.match?(~r/<\/a>/i, binary_part(left, start, byte_size(left) - start))

        nil ->
          false
      end

    tag || anchor
  end

  defp url(value) do
    {url, trailing} = trim_punctuation(value, "")

    {url, gt} =
      if String.ends_with?(url, "&gt;"),
        do: {String.replace_suffix(url, "&gt;", ""), "&gt;"},
        else: {url, ""}

    href = if Regex.match?(~r/\Awww\./i, url), do: "http://" <> url, else: url

    ~s(<a target="_blank" href="#{String.replace(href, "\"", "&quot;")}">#{url}</a>) <>
      Assets.html_escape(trailing) <> gt
  end

  defp trim_punctuation(value, trailing) do
    last = String.last(value)

    if last && !Regex.match?(~r/[\p{L}\p{M}\p{N}\p{Pc}\/\-=;]/u, last) do
      stripped = binary_part(value, 0, byte_size(value) - byte_size(last))
      opening = %{"]" => "[", ")" => "(", "}" => "{"}[last]

      if opening && count(stripped, opening) > count(stripped, last),
        do: {value, trailing},
        else: trim_punctuation(stripped, last <> trailing)
    else
      {value, trailing}
    end
  end

  defp count(value, character), do: length(:binary.matches(value, character))

  defp email(value) do
    href = "mailto:" <> (URI.encode_www_form(value) |> String.replace("%40", "@"))
    ~s(<a target="_blank" href="#{Assets.html_escape(href)}">#{Assets.html_escape(value)}</a>)
  end
end
