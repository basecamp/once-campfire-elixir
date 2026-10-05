defmodule Campfire.Chat do
  alias Campfire.{DB, Rails, RichText}
  def integer(n) when is_integer(n), do: n

  def integer(s) when is_binary(s) do
    case Integer.parse(String.trim_leading(s)) do
      {n, _} -> n
      _ -> 0
    end
  end

  def integer(_), do: 0
  def present?(v), do: is_binary(v) and String.trim(v) != ""

  def bot(key) do
    case String.split(String.trim(key), "-") do
      [id, token | _] ->
        DB.one("SELECT * FROM users WHERE id=? AND bot_token=? AND role=2 AND status=0", [
          integer(id),
          token
        ])

      _ ->
        nil
    end
  end

  def room(user, id),
    do:
      DB.one(
        "SELECT r.* FROM rooms r JOIN memberships m ON m.room_id=r.id WHERE r.id=? AND m.user_id=?",
        [integer(id), user["id"]]
      )

  def can_administer?(user, message), do: user["role"] == 1 or user["id"] == message["creator_id"]

  def messages(room, params) do
    cond do
      present?(params["before"]) ->
        page(room, params["before"], "<", "DESC")

      present?(params["after"]) ->
        page(room, params["after"], ">", "ASC")

      true ->
        DB.query(
          "SELECT * FROM messages WHERE room_id=? ORDER BY created_at DESC LIMIT 40",
          [room["id"]]
        )
        |> Enum.reverse()
    end
  end

  defp page(room, id, op, order) do
    case DB.one("SELECT * FROM messages WHERE room_id=? AND id=?", [room["id"], integer(id)]) do
      nil ->
        {:error, :not_found}

      m ->
        result =
          DB.query(
            "SELECT * FROM messages WHERE room_id=? AND created_at #{op} ? ORDER BY created_at #{order} LIMIT 40",
            [room["id"], m["created_at"]]
          )

        if order == "DESC", do: Enum.reverse(result), else: result
    end
  end

  def create_message(user, room, body, attrs \\ %{}) do
    body_present = !is_nil(body) || Map.has_key?(attrs, "body")
    body = if is_nil(body), do: nil, else: RichText.serialize(to_string(body))
    {:ok, attachment} = Campfire.Attachments.prepare(attrs["attachment"])
    embeds = Campfire.BlobEmbeds.blobs(body || "")
    plain = plain_text(body || "")
    plain = if attachment && !present?(plain), do: attachment["filename"], else: plain
    now = timestamp()

    result =
      DB.transaction(fn q ->
        [message] =
          q.(
            "INSERT INTO messages (creator_id,room_id,client_message_id,created_at,updated_at) VALUES (?,?,?,?,?) RETURNING *",
            [
              user["id"],
              room["id"],
              Campfire.Params.string(attrs["client_message_id"]) || uuid(),
              now,
              now
            ]
          )

        if body_present do
          [text] =
            q.(
              "INSERT INTO action_text_rich_texts (record_type,record_id,name,body,created_at,updated_at) VALUES ('Message',?,'body',?,?,?) RETURNING *",
              [message["id"], body, now, now]
            )

          Campfire.BlobEmbeds.sync(q, text["id"], embeds)
        end

        if attachment do
          Campfire.Attachments.save(q, attachment, "Message", message["id"], "attachment")
        end

        q.("INSERT INTO message_search_index (rowid,body) VALUES (?,?)", [
          message["id"],
          plain
        ])

        q.("UPDATE rooms SET updated_at=? WHERE id=?", [now, room["id"]])

        q.(
          "UPDATE memberships SET unread_at=?,updated_at=? WHERE room_id=? AND user_id != ? AND (connected_at IS NULL OR connected_at < ?) AND involvement != 'invisible'",
          [now, now, room["id"], user["id"], timestamp(Campfire.Clock.now() |> DateTime.add(-60))]
        )

        message
      end)

    if match?({:error, _}, result), do: Campfire.Attachments.discard(attachment)

    if is_map(result) do
      Campfire.Jobs.enqueue_push(room, result)
      Campfire.BlobEmbeds.committed({embeds, []})

      if blob = Campfire.Attachments.find("Message", result["id"], "attachment"),
        do: Campfire.Attachments.analyze_later(blob)
    end

    result
  end

  def update_message(message, body, attrs \\ %{}) do
    body_present = !is_nil(body) || Map.has_key?(attrs, "body")
    body = if is_nil(body), do: nil, else: RichText.serialize(to_string(body))

    old_text =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    plain =
      plain_text(
        if(body_present, do: body || "", else: if(old_text, do: old_text["body"] || "", else: ""))
      )

    embeds =
      if body_present && body not in [nil, ""], do: Campfire.BlobEmbeds.blobs(body), else: nil

    attachment_present = Map.has_key?(attrs, "attachment")
    {:ok, attachment} = Campfire.Attachments.prepare(attrs["attachment"])
    now = timestamp()

    result =
      DB.transaction(fn q ->
        old =
          List.first(
            q.(
              "SELECT b.* FROM active_storage_blobs b JOIN active_storage_attachments a ON a.blob_id=b.id WHERE a.record_type='Message' AND a.record_id=? AND a.name='attachment'",
              [message["id"]]
            )
          )

        changed = attachment_present && (old && old["id"]) != (attachment && attachment["id"])

        if changed do
          q.(
            "DELETE FROM active_storage_attachments WHERE record_type='Message' AND record_id=? AND name='attachment'",
            [message["id"]]
          )

          if attachment,
            do: Campfire.Attachments.save(q, attachment, "Message", message["id"], "attachment")
        end

        if body_present do
          existing =
            q.(
              "SELECT id FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
              [message["id"]]
            )

          if existing == [] do
            q.(
              "INSERT INTO action_text_rich_texts (record_type,record_id,name,body,created_at,updated_at) VALUES ('Message',?,'body',?,?,?)",
              [message["id"], body, now, now]
            )
          else
            q.(
              "UPDATE action_text_rich_texts SET body=?,updated_at=? WHERE record_type='Message' AND record_id=? AND name='body'",
              [body, now, message["id"]]
            )
          end
        end

        text =
          List.first(
            q.(
              "SELECT * FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
              [message["id"]]
            )
          )

        effects =
          if embeds && text, do: Campfire.BlobEmbeds.sync(q, text["id"], embeds), else: {[], []}

        blob = if attachment_present, do: attachment, else: old
        plain = if blob && !present?(plain), do: blob["filename"], else: plain

        client_id =
          if Map.has_key?(attrs, "client_message_id"),
            do: Campfire.Params.string(attrs["client_message_id"]),
            else: message["client_message_id"]

        q.("UPDATE messages SET client_message_id=?,updated_at=? WHERE id=?", [
          client_id,
          now,
          message["id"]
        ])

        q.("UPDATE message_search_index SET body=? WHERE rowid=?", [plain, message["id"]])
        q.("UPDATE rooms SET updated_at=? WHERE id=?", [now, message["room_id"]])

        {:updated,
         message |> Map.put("updated_at", now) |> Map.put("client_message_id", client_id),
         changed, old, attachment, effects}
      end)

    case result do
      {:updated, updated, changed, old, attachment, effects} ->
        Campfire.BlobEmbeds.committed(effects)
        if changed && old, do: Campfire.Attachments.purge_later(old)
        if changed && attachment, do: Campfire.Attachments.analyze_later(attachment)
        updated

      error ->
        error
    end
  end

  def delete_message(message) do
    result = DB.transaction(fn query -> {:deleted, delete_message_records(query, message)} end)

    case result do
      {:deleted, blobs} ->
        Enum.each(blobs, &Campfire.Attachments.purge_later/1)
        :ok

      error ->
        error
    end
  end

  # Used by dependent room destruction so all deletes commit together and purges
  # are enqueued only after that transaction succeeds.
  def delete_message_records(q, message) do
    blobs =
      q.(
        "SELECT b.* FROM active_storage_blobs b JOIN active_storage_attachments a ON a.blob_id=b.id WHERE (a.record_type='Message' AND a.record_id=?) OR (a.record_type='ActionText::RichText' AND a.record_id IN (SELECT id FROM action_text_rich_texts WHERE record_type='Message' AND record_id=?))",
        [message["id"], message["id"]]
      )

    q.(
      "DELETE FROM active_storage_attachments WHERE (record_type='Message' AND record_id=?) OR (record_type='ActionText::RichText' AND record_id IN (SELECT id FROM action_text_rich_texts WHERE record_type='Message' AND record_id=?))",
      [message["id"], message["id"]]
    )

    q.("DELETE FROM boosts WHERE message_id=?", [message["id"]])

    q.("DELETE FROM action_text_rich_texts WHERE record_type='Message' AND record_id=?", [
      message["id"]
    ])

    q.("DELETE FROM message_search_index WHERE rowid=?", [message["id"]])
    q.("DELETE FROM messages WHERE id=?", [message["id"]])
    q.("UPDATE rooms SET updated_at=? WHERE id=?", [timestamp(), message["room_id"]])
    blobs
  end

  def create_boost(user, message, content) do
    now = timestamp()

    DB.transaction(fn q ->
      [boost] =
        q.(
          "INSERT INTO boosts (booster_id,message_id,content,created_at,updated_at) VALUES (?,?,?,?,?) RETURNING *",
          [user["id"], message["id"], Campfire.Params.string(content), now, now]
        )

      q.("UPDATE messages SET updated_at=? WHERE id=?", [now, message["id"]])

      q.("UPDATE rooms SET updated_at=? WHERE id=?", [now, message["room_id"]])
      boost
    end)
  end

  def delete_boost(boost, message) do
    DB.transaction(fn q ->
      q.("DELETE FROM boosts WHERE id=?", [boost["id"]])
      q.("UPDATE messages SET updated_at=? WHERE id=?", [timestamp(), message["id"]])
      q.("UPDATE rooms SET updated_at=? WHERE id=?", [timestamp(), message["room_id"]])
      :ok
    end)
  end

  def present_boost(boost, message, base) do
    user = DB.one("SELECT * FROM users WHERE id=?", [boost["booster_id"]])

    %{
      "id" => boost["id"],
      "content" => boost["content"],
      "created_at" => iso_time(boost["created_at"]),
      "booster" => present_user(user, base),
      "message" => %{
        "id" => message["id"],
        "url" => base <> "/rooms/#{message["room_id"]}/messages/#{message["id"]}"
      }
    }
  end

  def present_message(message, base) do
    text =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    body = if text, do: text["body"], else: nil
    user = DB.one("SELECT * FROM users WHERE id=?", [message["creator_id"]])

    %{
      "id" => message["id"],
      "created_at" => iso_time(message["created_at"]),
      "body" => %{
        "plain_text" => plain_text_body(message, body || ""),
        "html" => if(is_nil(body), do: "", else: RichText.render(body))
      },
      "creator" => present_user(user, base),
      "room" => %{"id" => message["room_id"]},
      "url" => base <> "/rooms/#{message["room_id"]}/messages/#{message["id"]}"
    }
  end

  def present_user(user, base) do
    avatar = Rails.signed_id("User", user["id"], "avatar")
    version = user["updated_at"] |> String.replace(~r/[^0-9]/, "") |> String.slice(0, 14)

    %{
      "id" => user["id"],
      "name" => user["name"],
      "role" => Enum.at(["member", "administrator", "bot"], user["role"]),
      "avatar_url" => base <> "/users/#{avatar}/avatar?v=#{version}"
    }
  end

  def plain_text_body(message, body) do
    plain = plain_text(body)

    if present?(plain),
      do: plain,
      else:
        (Campfire.Attachments.find("Message", message["id"], "attachment") || %{})["filename"] ||
          ""
  end

  def plain_text(html), do: RichText.plain_text(html)

  def iso_time(time) do
    {:ok, d, _} = DateTime.from_iso8601(String.replace(time, " ", "T") <> "Z")

    Calendar.strftime(d, "%Y-%m-%dT%H:%M:%S") <>
      "." <> String.pad_leading(to_string(div(elem(d.microsecond, 0), 1000)), 3, "0") <> "Z"
  end

  def timestamp, do: timestamp(Campfire.Clock.now())

  def timestamp(time),
    do:
      time
      |> DateTime.to_naive()
      |> NaiveDateTime.to_iso8601()
      |> String.replace("T", " ")

  def uuid do
    <<a::32, b::16, _::4, c::12, _::2, d::14, e::48>> = :crypto.strong_rand_bytes(16)

    Enum.zip([a, b, Bitwise.bor(c, 0x4000), Bitwise.bor(d, 0x8000), e], [8, 4, 4, 4, 12])
    |> Enum.map_join("-", fn {n, l} ->
      n |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(l, "0")
    end)
  end
end
