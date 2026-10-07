defmodule Campfire.MessagesView do
  alias Campfire.{Assets, DB, Mentions, RichText}
  require EEx
  @csrf_placeholder "<!--campfire-csrf-input-->"
  EEx.function_from_file(:defp, :item, "priv/templates/message.html.eex", [:assigns])
  EEx.function_from_file(:defp, :boost_html, "priv/templates/boost.html.eex", [:assigns])

  EEx.function_from_file(:defp, :boosts_html, "priv/templates/boosts.html.eex", [:assigns])

  def render(message, base, csrf \\ nil) do
    :message
    |> Campfire.FragmentCache.record(message, fn ->
      render_fragment(message, base, if(csrf, do: :placeholder))
    end)
    |> put_csrf(csrf)
  rescue
    _ -> failed_fragment()
  end

  def render_many(messages, base, csrf), do: Enum.map_join(messages, &render(&1, base, csrf))

  defp render_fragment(message, base, csrf) do
    creator = DB.one("SELECT * FROM users WHERE id=?", [message["creator_id"]])
    room = DB.one("SELECT * FROM rooms WHERE id=?", [message["room_id"]])

    text =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    body = if text, do: text["body"], else: nil

    title =
      [creator["name"], creator["bio"]]
      |> Enum.reject(&(is_nil(&1) || String.trim(&1) == ""))
      |> Enum.join(" – ")

    name = Campfire.RoomPage.display_name(room, nil)

    item(
      id: message["id"],
      client_id: Assets.html_escape(message["client_message_id"]),
      room_id: room["id"],
      creator_id: creator["id"],
      creator_name: Assets.html_escape(creator["name"]),
      creator_title: Assets.html_escape(title),
      avatar: Mentions.avatar(creator, :page),
      room_name: Assets.html_escape(name),
      base: Assets.html_escape(base),
      created_epoch: epoch(message["created_at"]),
      updated_epoch: epoch(message["updated_at"]),
      created_iso: iso(message["created_at"]),
      emoji_class:
        if(all_emoji?(RichText.plain_text(body || "")), do: "message--emoji", else: ""),
      presentation: presentation_fragment(message, body),
      attachment_actions: attachment_actions(message),
      boosting: render_boosts(message, csrf),
      csrf_input: csrf_input(csrf)
    )
  end

  defp failed_fragment,
    do:
      "<div class=\"message message--formatted message--failed center\">\n  <div class=\"message__body\">\n    <div class=\"message__body-content txt-align-center\">\n      Failed to load message content\n    </div>\n  </div>\n</div>\n"

  defp attachment_actions(message) do
    if blob = Campfire.Attachments.find("Message", message["id"], "attachment") do
      path = Assets.html_escape(Campfire.Storage.blob_path(blob))
      filename = Assets.html_escape(Campfire.Filename.sanitized(blob["filename"]))

      """
                <a class="btn message__action-btn center full-width hide-in-ios-pwa" title="Download" aria-label="Download" href="#{path}?disposition=attachment">
                  <img class="colorize--black" aria-hidden="true" src="#{Assets.path("download.svg")}" width="20" height="20" />
      </a>
                <button class="btn message__action-btn center full-width" data-controller="web-share" data-action="web-share#share" data-web-share-files-value="#{path}" data-web-share-title-value="#{filename}" title="Share" aria-label="Share">
                  <img class="colorize--black" aria-hidden="true" src="#{Assets.path("share.svg")}" width="20" height="20" />
      </button>
      """
    else
      """
                <button class="btn message__action-btn center full-width" data-action="reply#reply" title="Reply" aria-label="Reply">
                  <img class="colorize--black" aria-hidden="true" src="#{Assets.path("reply.svg")}" width="20" height="20" />
      </button>
      """
    end
  end

  def render_boosts(message, csrf \\ nil) do
    boosts_html(
      client_id: Assets.html_escape(message["client_message_id"]),
      id: message["id"],
      boosts:
        DB.query("SELECT * FROM boosts WHERE message_id=? ORDER BY created_at", [message["id"]])
        |> Enum.map_join(&render_boost(&1, csrf))
    )
    |> String.trim_trailing("\n")
  end

  def render_boost(boost, csrf \\ nil) do
    :boost
    |> Campfire.FragmentCache.record(boost, fn ->
      render_boost_fragment(boost, if(csrf, do: :placeholder))
    end)
    |> put_csrf(csrf)
  end

  defp render_boost_fragment(boost, csrf) do
    booster = DB.one("SELECT * FROM users WHERE id=?", [boost["booster_id"]])

    avatar =
      Mentions.avatar(booster, :page)
      |> String.replace(
        ~s(aria-hidden="true"),
        ~s(aria-label="#{Assets.html_escape(booster["name"] <> " boosted " <> boost["content"])}")
      )

    boost_html(
      id: boost["id"],
      booster_id: booster["id"],
      message_id: boost["message_id"],
      content: Assets.html_escape(boost["content"]),
      emoji: all_emoji?(boost["content"]),
      avatar: avatar,
      csrf_input: csrf_input(csrf)
    )
  end

  defp csrf_input(:placeholder), do: @csrf_placeholder
  defp csrf_input(nil), do: ""

  defp csrf_input(token),
    do: ~s(<input type="hidden" name="authenticity_token" value="#{Assets.html_escape(token)}" />)

  defp put_csrf(html, :placeholder), do: html
  defp put_csrf(html, token), do: String.replace(html, @csrf_placeholder, csrf_input(token))

  def presentation_element(message) do
    text =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    body = if text, do: text["body"], else: nil

    ~s(<div id="presentation_message_#{Assets.html_escape(message["client_message_id"])}" dir="auto" data-reply-target="body" data-messages-target="body">\n  #{presentation_message(message, body)}\n</div>\n)
  end

  def all_emoji?(text),
    do: Regex.match?(~r/\A(\p{Emoji_Presentation}|\p{Extended_Pictographic}|\x{FE0F})+\z/u, text)

  def presentation_message(message, body) do
    present(message, body, &presentation/1)
  end

  defp presentation_fragment(message, body) do
    present(message, body, &presentation!/1)
  end

  defp present(message, body, render) do
    blob = Campfire.Attachments.find("Message", message["id"], "attachment")
    sound = Campfire.Sounds.find(Campfire.Chat.plain_text_body(message, body || ""))

    cond do
      blob -> Campfire.AttachmentView.render(blob)
      sound -> Campfire.Sounds.render(sound)
      true -> render.(body)
    end
  end

  def presentation(body) do
    presentation!(body)
  rescue
    _ -> ""
  end

  defp presentation!(nil), do: ""

  defp presentation!(body) do
    body
    |> RichText.parse()
    |> remove_solo_link()
    |> filter()
    |> Floki.raw_html()
    |> RichText.render()
    |> RichText.raw_parse()
    |> final_sanitize()
    |> RichText.serialize_nodes()
    |> Campfire.Autolink.render()
  end

  defp remove_solo_link(nodes) do
    embeds =
      Floki.find(
        nodes,
        "action-text-attachment[content-type='application/vnd.actiontext.opengraph-embed']"
      )

    plain = RichText.plain_text(Floki.raw_html(nodes))

    if length(embeds) == 1 do
      [{_, attrs, _} = attachment] = embeds
      embed = Campfire.OpengraphEmbed.resolve(attrs)

      if embed && normalize_tweet(embed["href"]) == normalize_tweet(plain) do
        if Floki.find(nodes, "div") != [] do
          replace_divs(nodes, attachment)
        else
          remove_paragraphs(nodes)
        end
      else
        nodes
      end
    else
      nodes
    end
  end

  defp normalize_tweet(value) when is_binary(value) do
    if String.contains?(String.trim(value), ["x.com", "twitter.com"]) do
      uri = URI.parse(value)
      host = if String.downcase(uri.host || "") == "x.com", do: "twitter.com", else: uri.host
      URI.to_string(%{uri | host: host, query: nil})
    else
      value
    end
  rescue
    ArgumentError -> value
  end

  defp normalize_tweet(value), do: value

  defp replace_divs(nodes, attachment),
    do:
      Enum.map(nodes, fn
        {"div", attrs, _} -> {"div", attrs, [attachment]}
        {tag, attrs, children} -> {tag, attrs, replace_divs(children, attachment)}
        text -> text
      end)

  defp remove_paragraphs(nodes),
    do:
      Enum.flat_map(nodes, fn
        {"p", _, _} = node ->
          if Floki.find([node], "action-text-attachment") == [], do: [], else: [node]

        {tag, attrs, children} ->
          [{tag, attrs, remove_paragraphs(children)}]

        text ->
          [text]
      end)

  defp final_sanitize(nodes) do
    tags =
      ~w(a abbr acronym address b big blockquote br cite code dd del dfn div dl dt em h1 h2 h3 h4 h5 h6 hr i img ins kbd li ol p pre samp small span strong sub sup time tt ul var s u mark table thead tbody tfoot tr th td)

    attributes =
      ~w(abbr alt cite class datetime height href lang name src title width xml:lang data-language)

    Enum.flat_map(nodes, fn
      {tag, attrs, children} ->
        children = final_sanitize(children)

        if tag in tags,
          do: [
            {tag,
             Enum.filter(attrs, fn {key, _} -> key in attributes end)
             |> then(&RichText.sanitize_attributes(tag, &1)), children}
          ],
          else: children

      text when is_binary(text) ->
        [text]

      _ ->
        []
    end)
  end

  defp filter(nodes) do
    allowed =
      ~w(a abbr acronym address b big blockquote br cite code dd del dfn div dl dt em h1 h2 h3 h4 h5 h6 hr i ins kbd li ol p pre samp small span strong sub sup time tt ul var s u mark table thead tbody tfoot tr th td action-text-attachment figure figcaption)

    Enum.flat_map(nodes, fn
      {tag, attrs, children} ->
        attributes =
          ~w(abbr alt cite class datetime height href lang name src title width xml:lang style data-language sgid content-type url filename filesize previewable presentation caption content)

        if tag in allowed do
          attrs = Enum.filter(attrs, fn {key, _} -> key in attributes end)
          [{tag, RichText.sanitize_attributes(tag, attrs), filter(children)}]
        else
          []
        end

      text when is_binary(text) ->
        [text]

      _ ->
        []
    end)
  end

  def epoch(value) do
    {:ok, date, _} = DateTime.from_iso8601(String.replace(value, " ", "T") <> "Z")
    DateTime.to_unix(date, :millisecond)
  end

  def iso(value) do
    {:ok, date, _} = DateTime.from_iso8601(String.replace(value, " ", "T") <> "Z")
    DateTime.to_iso8601(%{date | microsecond: {0, 0}})
  end
end
