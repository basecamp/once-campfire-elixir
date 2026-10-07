defmodule Campfire.RichText do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils

  @moduledoc "Action Text fragment rendering and plain-text conversion. Pinned Action Text attachment expansion and HTML serialization."
  @tags ~w(a abbr acronym address b big blockquote br cite code dd del dfn div dl dt em h1 h2 h3 h4 h5 h6 hr i img ins kbd li ol p pre samp small span strong sub sup time tt ul var s u mark table thead tbody tfoot tr th td figure figcaption action-text-attachment)
  @attributes ~w(abbr alt cite class datetime height href lang name src title width xml:lang align style data-language sgid content-type url filename filesize width height previewable presentation caption content)
  @void ~w(br hr img)
  @css ~w(color background-color font-size font-style font-weight font-family text-align text-decoration margin padding border border-color border-width border-style width height)
  def raw_parse(html), do: Campfire.HtmlParser.parse(html)

  def parse(html) do
    html = Regex.replace(~r/\A[\x00\x09-\x0d ]+|[\x00\x09-\x0d ]+\z/, html, "")

    html |> raw_parse() |> Campfire.ContentCanonical.nodes()
  end

  def render(html),
    do:
      "<div class=\"lexxy-content\">\n  " <>
        (if(String.trim(html) == "", do: "", else: html)
         |> parse()
         |> Enum.map_join(&render_node/1)) <> "\n</div>\n"

  def plain_text(html) do
    if String.trim(html) == "" do
      ""
    else
      html
      |> parse()
      |> expand_plain_nodes()
      |> plain_nodes([])
      |> chomp()
    end
  end

  defp expand_plain_nodes(nodes),
    do:
      Enum.flat_map(nodes, fn
        {"action-text-attachment", attrs, _} ->
          data = Map.new(attrs)
          embed = Campfire.OpengraphEmbed.resolve(attrs)
          user = if is_nil(embed), do: Campfire.Mentions.resolve(attrs)
          blob = Campfire.BlobEmbeds.resolve(attrs)
          caption = if Campfire.Chat.present?(data["caption"]), do: data["caption"]
          type = data["content-type"] || ""

          replacement =
            cond do
              embed ->
                ""

              user ->
                "@" <> user["name"]

              blob ->
                "[#{caption || blob["filename"]}]"

              String.contains?(type, "html") && Campfire.Chat.present?(data["content"]) ->
                data["content"] |> parse() |> Enum.map_join(&render_plain_content/1)

              data["url"] && Regex.match?(~r/^image(?:\/.+|$)/, type) ->
                "[#{caption || "Image"}]"

              data["url"] && Regex.match?(~r/^video(?:\/.+|$)/, type) ->
                "[#{caption || data["filename"] || "Video"}]"

              true ->
                caption || ""
            end

          raw_parse(replacement)

        {tag, attrs, children} ->
          [{tag, attrs, expand_plain_nodes(children)}]

        text when is_binary(text) ->
          [text]

        _ ->
          []
      end)

  defp render_plain_content({tag, attrs, children}) do
    body = Enum.map_join(children, &render_plain_content/1)

    if tag in @tags,
      do: element(tag, Enum.filter(attrs, fn {key, _} -> key in @attributes end), body),
      else: body
  end

  defp render_plain_content(text) when is_binary(text), do: escape_text(text)
  defp render_plain_content(_), do: ""

  def serialize_nodes(nodes), do: Enum.map_join(nodes, &serialize_node/1)
  def serialize(html), do: html |> parse() |> Enum.map_join(&serialize_node/1)
  defp render_node(text) when is_binary(text), do: escape_text(text)

  defp render_node({"action-text-attachment", attrs, _children}) do
    blob = Campfire.BlobEmbeds.resolve(attrs)
    embed = Campfire.OpengraphEmbed.resolve(attrs)
    user = if is_nil(embed), do: Campfire.Mentions.resolve(attrs)
    data = Map.new(attrs)
    type = data["content-type"] || ""

    body =
      cond do
        user ->
          Campfire.Mentions.html(user)

        blob ->
          Campfire.BlobEmbeds.render(blob, attrs)

        embed ->
          Campfire.OpengraphEmbed.render(embed) |> String.trim_trailing("\n")

        String.contains?(type, "html") && Campfire.Chat.present?(data["content"]) ->
          sanitized = data["content"] |> raw_parse() |> Enum.map_join(&render_plain_content/1)

          if String.trim(sanitized) == "" do
            "☒"
          else
            content = sanitized |> parse() |> Enum.map_join(&render_node/1)
            "<figure class=\"attachment attachment--content\">\n  #{content}\n\n</figure>"
          end

        data["url"] && Regex.match?(~r/^image(?:\/.+|$)/, type) ->
          dimensions = for key <- ~w(width height), data[key], do: {key, data[key]}

          if Regex.match?(~r/\A(?:javascript|vbscript):/i, data["url"]),
            do: raise(ArgumentError, "unknown image asset")

          image =
            element("img", sanitize_attributes("img", dimensions ++ [{"src", data["url"]}]), "")

          caption =
            if Campfire.Chat.present?(data["caption"]),
              do:
                "    <figcaption class=\"attachment__caption\">\n      #{escape_text(data["caption"])}\n    </figcaption>\n",
              else: ""

          "<figure class=\"attachment attachment--preview\">\n  #{image}\n#{caption}</figure>"

        data["url"] && Regex.match?(~r/^video(?:\/.+|$)/, type) ->
          "<figure class=\"attachment attachment--preview attachment--video\">\n  <video controls=\"controls\">\n    <source src=\"#{escape_attr(data["url"])}\" type=\"#{escape_attr(type)}\">\n</video>#{if Campfire.Chat.present?(data["caption"]), do: "    <figcaption class=\"attachment__caption\">\n      #{escape_text(data["caption"])}\n    </figcaption>\n", else: ""}</figure>"

        Enum.all?(attrs, fn {key, _} ->
          key not in ~w(sgid content-type url href filename filesize width height previewable presentation caption content)
        end) ->
          raise ArgumentError, "empty Action Text attachment"

        true ->
          if Campfire.Mentions.missing_known_model?(attrs),
            do: raise(ArgumentError, "missing attachable partial"),
            else: "☒"
      end

    attrs =
      Enum.filter(attrs, fn {name, _} -> name in @attributes end)
      |> Enum.flat_map(&safe_attribute/1)

    element("action-text-attachment", attrs, body)
  end

  defp render_node({"div", _attrs, children} = node) do
    if Campfire.ContentCanonical.gallery?(children) do
      members = Enum.reject(children, &is_binary/1)

      previous = Process.get(:campfire_blob_gallery, false)
      Process.put(:campfire_blob_gallery, true)

      try do
        "<div class=\"attachment-gallery attachment-gallery--#{length(members)}\">\n  #{Enum.map_join(members, &render_node/1)}\n</div>"
      after
        Process.put(:campfire_blob_gallery, previous)
      end
    else
      render_element(node)
    end
  end

  defp render_node({tag, attrs, children}), do: render_element({tag, attrs, children})
  defp render_node(_), do: ""

  defp render_element({tag, attrs, children}) do
    body = Enum.map_join(children, &render_node/1)

    if tag in @tags do
      attrs =
        Enum.filter(attrs, fn {name, _} -> name in @attributes end)
        |> then(&sanitize_attributes(tag, &1))

      element(tag, attrs, body)
    else
      body
    end
  end

  defp serialize_node(text) when is_binary(text), do: escape_text(text)

  defp serialize_node({tag, attrs, children}),
    do: element(tag, attrs, Enum.map_join(children, &serialize_node/1))

  defp serialize_node(_), do: ""

  def sanitize_attributes(tag, attrs), do: scrub_attributes(tag, attrs, [])

  # Rails::HTML::PermitScrubber calls force_correct_attribute_escaping! on
  # the entire node after each surviving attribute, not after the whole pass.
  # A later URI therefore sees spaces/quotes escaped by an earlier attribute.
  defp scrub_attributes(_tag, [], kept), do: kept

  defp scrub_attributes(tag, [attr | rest], kept) do
    case safe_attribute(attr) do
      [] when elem(attr, 0) != "style" ->
        scrub_attributes(tag, rest, kept)

      surviving ->
        escaped = force_attribute_escaping(tag, kept ++ surviving ++ rest)
        keep_count = length(kept) + length(surviving)
        {kept, rest} = Enum.split(escaped, keep_count)
        scrub_attributes(tag, rest, kept)
    end
  end

  defp force_attribute_escaping(tag, attrs) do
    Enum.map(attrs, fn {name, value} ->
      if name in ~w(href action src) || (tag == "a" && name == "name") do
        value =
          Regex.replace(~r/[\x00-\x08\x0b\x0c\x0e-\x1f]/, value, "")
          |> String.replace(" ", "%20")
          |> String.replace("\"", "%22")

        {name, value}
      else
        {name, value}
      end
    end)
  end

  defp safe_attribute({"style", value}) do
    value =
      value
      |> String.split(";")
      |> Enum.flat_map(fn item ->
        case String.split(item, ":", parts: 2) do
          [key, value] ->
            key = String.trim(key) |> String.downcase()
            value = String.trim(value)

            if key in @css and not Regex.match?(~r/url\s*\(|expression|[<>\\]/i, value),
              do: [key <> ":" <> value <> ";"],
              else: []

          _ ->
            []
        end
      end)
      |> Enum.join(" ")

    if value == "", do: [], else: [{"style", value}]
  end

  defp safe_attribute({name, value})
       when name in ~w(href src cite action longdesc poster preload xlink:href xml:base) do
    normalized = value |> String.replace(~r/[`\x00-\x20\x7f-\x{101}]/u, "") |> String.downcase()

    normalized =
      normalized
      |> String.replace("&tab;", "")
      |> String.replace("&newline;", "")
      |> String.replace("&colon;", ":")

    protocols =
      ~w(afs aim callto data ed2k fax ftp gopher http https irc line mailto modem news nntp rsync rtsp sftp sms ssh tag tel telnet urn webcal xmpp)

    allowed =
      case Regex.run(~r/\A([a-z][a-z0-9+.-]*)(?::|%3a|&#0*58;?|&#x0*3a;?|&#37;3a)/, normalized) do
        [_, "data"] ->
          Regex.match?(
            ~r/\Adata:(image\/(?:gif|jpeg|png)|text\/(?:css|plain))(?:;|,)/,
            normalized
          )

        [_, scheme] ->
          scheme in protocols

        _ ->
          true
      end

    if allowed, do: [{name, value}], else: []
  end

  defp safe_attribute(attr), do: [attr]

  defp element(tag, attrs, body) do
    attrs =
      Enum.map_join(attrs, fn {name, value} ->
        " " <> name <> "=\"" <> escape_attr(value) <> "\""
      end)

    if tag in @void, do: "<#{tag}#{attrs}>", else: "<#{tag}#{attrs}>#{body}</#{tag}>"
  end

  defp escape_text(text),
    do:
      text
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> String.replace("\u00a0", "&nbsp;")

  defp escape_attr(text), do: escape_text(text) |> String.replace("\"", "&quot;")

  defp plain_nodes(nodes, ancestors) do
    {text, _} =
      Enum.map_reduce(nodes, 0, fn node, index ->
        {plain_node(node, ancestors, index), if(is_tuple(node), do: index + 1, else: index)}
      end)

    Enum.join(text)
  end

  defp plain_node(text, _, _) when is_binary(text), do: chomp(text)

  defp plain_node({tag, _, children}, ancestors, index) do
    text = plain_nodes(children, [tag | ancestors])
    lists = Enum.filter(ancestors, &(&1 in ["ul", "ol"]))

    case tag do
      tag when tag in ["script", "style"] ->
        ""

      "br" ->
        "\n"

      tag when tag in ["p", "h1"] ->
        chomp(text) <> "\n\n"

      "div" ->
        chomp(text) <> "\n"

      "figcaption" ->
        "[#{chomp(text)}]"

      tag when tag in ["ul", "ol"] ->
        if(lists == [], do: "", else: "\n") <> chomp(text) <> "\n\n"

      "li" ->
        bullet = if List.first(lists) == "ol", do: "#{index + 1}.", else: "•"
        String.duplicate("  ", max(length(lists) - 1, 0)) <> bullet <> " " <> chomp(text) <> "\n"

      "blockquote" ->
        quote_block(chomp(text) <> "\n\n")

      _ ->
        text
    end
  end

  defp plain_node(_, _, _), do: ""

  defp quote_block(text) do
    case Regex.scan(~r/[^\x09-\x0d ]/u, text, return: :index) do
      [] ->
        "“”"

      matches ->
        [{start, _}] = List.first(matches)
        [{last, length}] = List.last(matches)
        finish = last + length

        binary_part(text, 0, start) <>
          "“" <>
          binary_part(text, start, finish - start) <>
          "”" <> binary_part(text, finish, byte_size(text) - finish)
    end
  end

  defp chomp(text), do: String.replace(text, ~r/(?:\r?\n)+$/, "")
end
