defmodule Campfire.MessagesView do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  alias Campfire.{Assets, DB, Mentions, RichText}
  require EEx
  EEx.function_from_file(:defp, :item, "priv/templates/message.html.eex", [:assigns])
  EEx.function_from_file(:defp, :boost_html, "priv/templates/boost.html.eex", [:assigns])

  EEx.function_from_file(:defp, :boosts_html, "priv/templates/boosts.html.eex", [:assigns])

  EEx.function_from_file(
    :defp,
    :attachment_actions_html,
    "priv/templates/message_attachment_actions.html.eex",
    [:assigns]
  )

  EEx.function_from_file(
    :defp,
    :reply_action_html,
    "priv/templates/message_reply_action.html.eex",
    [:assigns]
  )

  def render(message, base) do
    :message
    |> Campfire.FragmentCache.record(message, fn ->
      render_fragment(message, base, nil)
    end)
  rescue
    _ -> failed_fragment()
  end

  def render_many(messages, base) do
    entries = Enum.map(messages, &{:message, &1})

    Campfire.FragmentCache.fetch_many(entries, fn missed ->
      loaded = preload(missed)
      Enum.map(missed, fn {:message, message} -> render_safely(message, base, loaded) end)
    end)
    |> Enum.join()
  end

  # A page's misses are rendered from one batched read set rather than a query per message, and a
  # fully warm page runs no read at all.
  defp preload(entries) do
    messages = Enum.map(entries, fn {:message, message} -> message end)
    ids = Enum.map(messages, & &1["id"])

    # A page's reads run as a handful of batched statements inside one read transaction per chunk,
    # rather than five statements per message.
    messages_by_id = Map.new(messages, &{&1["id"], &1})

    boosts =
      in_chunks(ids, fn placeholders, chunk ->
        [rows] =
          DB.read_batch([
            {
              "SELECT * FROM boosts WHERE message_id IN (#{placeholders}) ORDER BY message_id, created_at, id",
              chunk
            }
          ])

        rows
      end)

    boosts_by_message = Enum.group_by(boosts, & &1["message_id"])

    {users, rooms, bodies} =
      ids
      |> Enum.chunk_every(400)
      |> Enum.reduce({[], [], []}, fn chunk, {users, rooms, bodies} ->
        chunk_messages = Enum.map(chunk, &Map.fetch!(messages_by_id, &1))
        creator_ids = Enum.map(chunk_messages, & &1["creator_id"])
        room_ids = Enum.map(chunk_messages, & &1["room_id"])

        booster_ids =
          chunk
          |> Enum.flat_map(&Map.get(boosts_by_message, &1, []))
          |> Enum.map(& &1["booster_id"])

        user_ids = Enum.uniq(creator_ids ++ booster_ids)
        chunk_room_ids = Enum.uniq(room_ids)

        [chunk_users, chunk_rooms, chunk_bodies] =
          DB.read_batch([
            {"SELECT * FROM users WHERE id IN (#{placeholders(user_ids)})", user_ids},
            {"SELECT * FROM rooms WHERE id IN (#{placeholders(chunk_room_ids)})", chunk_room_ids},
            {
              "SELECT record_id, body FROM action_text_rich_texts WHERE record_type='Message' AND record_id IN (#{placeholders(chunk)}) AND name='body'",
              chunk
            }
          ])

        {users ++ chunk_users, rooms ++ chunk_rooms, bodies ++ chunk_bodies}
      end)

    attachments =
      in_chunks(ids, fn _placeholders, chunk ->
        Campfire.Attachments.find_many("Message", chunk, "attachment")
      end)

    %{
      users: Map.new(users, &{&1["id"], &1}),
      rooms: Map.new(rooms, &{&1["id"], &1}),
      bodies: Map.new(bodies, &{&1["record_id"], &1["body"]}),
      boosts: Enum.group_by(boosts, & &1["message_id"]),
      attachments: Map.new(attachments, &{&1["record_id"], &1})
    }
  end

  defp placeholders(list), do: Enum.map_join(list, ",", fn _ -> "?" end)

  defp in_chunks([], _query), do: []

  defp in_chunks(ids, query) do
    ids
    |> Enum.chunk_every(400)
    |> Enum.flat_map(fn chunk ->
      placeholders = Enum.map_join(chunk, ",", fn _ -> "?" end)
      query.(placeholders, chunk)
    end)
  end

  defp user(id, nil), do: DB.one("SELECT * FROM users WHERE id=?", [id])
  defp user(id, %{users: users}), do: Map.get(users, id)

  defp room(id, nil), do: DB.one("SELECT * FROM rooms WHERE id=?", [id])
  defp room(id, %{rooms: rooms}), do: Map.get(rooms, id)

  defp body(id, nil) do
    case DB.one(
           "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
           [id]
         ) do
      nil -> nil
      text -> text["body"]
    end
  end

  defp body(id, %{bodies: bodies}), do: Map.get(bodies, id)

  defp attachment(id, nil), do: Campfire.Attachments.find("Message", id, "attachment")
  defp attachment(id, %{attachments: attachments}), do: Map.get(attachments, id)

  defp boosts(message, nil) do
    DB.query("SELECT * FROM boosts WHERE message_id=? ORDER BY created_at", [message["id"]])
  end

  defp boosts(message, %{boosts: boosts}), do: Map.get(boosts, message["id"], [])

  defp render_safely(message, base, loaded) do
    render_fragment(message, base, loaded)
  rescue
    _ -> failed_fragment()
  end

  defp render_fragment(message, base, loaded) do
    creator = user(message["creator_id"], loaded)
    room = room(message["room_id"], loaded)
    body = body(message["id"], loaded)

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
      attachment_actions: attachment_actions(message, loaded),
      boosting: render_boosts(message, loaded)
    )
  end

  defp failed_fragment,
    do:
      "<div class=\"message message--formatted message--failed center\">\n  <div class=\"message__body\">\n    <div class=\"message__body-content txt-align-center\">\n      Failed to load message content\n    </div>\n  </div>\n</div>\n"

  defp attachment_actions(message, loaded) do
    if blob = attachment(message["id"], loaded) do
      path = Assets.html_escape(Campfire.Storage.blob_path(blob))
      filename = Assets.html_escape(Campfire.Filename.sanitized(blob["filename"]))

      attachment_actions_html(%{
        path: path,
        filename: filename,
        download_icon: Assets.path("download.svg"),
        share_icon: Assets.path("share.svg")
      })
    else
      reply_action_html(%{reply_icon: Assets.path("reply.svg")})
    end
  end

  def render_boosts(message, loaded \\ nil) do
    boosts_html(
      client_id: Assets.html_escape(message["client_message_id"]),
      id: message["id"],
      boosts:
        message
        |> boosts(loaded)
        |> Enum.map(&{:boost, &1})
        |> Campfire.FragmentCache.fetch_many(fn missed ->
          Enum.map(missed, fn {:boost, boost} -> render_boost_fragment(boost, loaded) end)
        end)
        |> Enum.join()
    )
    |> String.trim_trailing("\n")
  end

  def render_boost(boost) do
    :boost
    |> Campfire.FragmentCache.record(boost, fn ->
      render_boost_fragment(boost, nil)
    end)
  end

  defp render_boost_fragment(boost, loaded) do
    booster = user(boost["booster_id"], loaded)

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
      avatar: avatar
    )
  end

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

    if match?([_], embeds) do
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
