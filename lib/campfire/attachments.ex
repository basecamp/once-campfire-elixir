defmodule Campfire.Attachments do
  alias Campfire.{Chat, DB, Jobs, Mime, Rails, Storage, StorageMedia}

  def find(type, id, name) do
    DB.one(
      "SELECT b.* FROM active_storage_attachments a JOIN active_storage_blobs b ON b.id=a.blob_id WHERE a.record_type=? AND a.record_id=? AND a.name=?",
      [type, id, name]
    )
  end

  def prepare(nil), do: {:ok, nil}
  def prepare(""), do: {:ok, nil}

  def prepare(%Plug.Upload{path: path, filename: filename, content_type: type}),
    do: prepare_bytes(File.read!(path), filename, type)

  def prepare(token) when is_binary(token) do
    with id when is_integer(id) <- Rails.verify_message("ActiveStorage", token, "blob_id"),
         blob when is_map(blob) <- DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [id]) do
      metadata = Jason.decode!(blob["metadata"] || "{}")

      if metadata["identified"] do
        {:ok, blob}
      else
        type =
          Mime.identify(
            File.read!(Storage.path(blob["key"])),
            blob["filename"],
            blob["content_type"]
          )

        values = Campfire.JSON.pairs(Campfire.JSON.decode!(blob["metadata"] || "{}"))

        {:ok,
         blob
         |> Map.put("content_type", type)
         |> Map.put(
           "metadata",
           Rails.json(values ++ [{"identified", true}])
         )}
      end
    else
      _ -> {:error, :invalid_signature}
    end
  end

  def prepare_bytes(bytes, filename, type) do
    key = Campfire.Random.token(28, "0123456789abcdefghijklmnopqrstuvwxyz")
    path = Storage.path(key)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, bytes)

    {:ok,
     %{
       "key" => key,
       "filename" => filename,
       "content_type" => Mime.identify(bytes, filename, type),
       "metadata" => "{\"identified\":true}",
       "service_name" => "local",
       "byte_size" => byte_size(bytes),
       "checksum" => Base.encode64(:crypto.hash(:md5, bytes)),
       "created_at" => Chat.timestamp()
     }}
  end

  def persist(prepared) do
    DB.one(
      "INSERT INTO active_storage_blobs (key,filename,content_type,metadata,service_name,byte_size,checksum,created_at) VALUES (?,?,?,?,?,?,?,?) RETURNING *",
      Enum.map(
        ~w(key filename content_type metadata service_name byte_size checksum created_at),
        &prepared[&1]
      )
    )
  end

  def save(q, blob, type, id, name) do
    blob =
      if blob["id"] do
        [updated] =
          q.("UPDATE active_storage_blobs SET content_type=?,metadata=? WHERE id=? RETURNING *", [
            blob["content_type"],
            blob["metadata"],
            blob["id"]
          ])

        updated
      else
        [created] =
          q.(
            "INSERT INTO active_storage_blobs (key,filename,content_type,metadata,service_name,byte_size,checksum,created_at) VALUES (?,?,?,?,?,?,?,?) RETURNING *",
            Enum.map(
              ~w(key filename content_type metadata service_name byte_size checksum created_at),
              &blob[&1]
            )
          )

        created
      end

    q.(
      "INSERT INTO active_storage_attachments (name,record_type,record_id,blob_id,created_at) VALUES (?,?,?,?,?)",
      [name, type, id, blob["id"], Chat.timestamp()]
    )

    blob
  end

  def touch_records(query, blob_id) do
    for attachment <-
          query.("SELECT record_type,record_id FROM active_storage_attachments WHERE blob_id=?", [
            blob_id
          ]) do
      case attachment["record_type"] do
        "Message" ->
          touch_message(query, attachment["record_id"])

        "ActionText::RichText" ->
          query.("UPDATE action_text_rich_texts SET updated_at=? WHERE id=?", [
            Chat.timestamp(),
            attachment["record_id"]
          ])

          for text <-
                query.(
                  "SELECT record_id FROM action_text_rich_texts WHERE id=? AND record_type='Message'",
                  [attachment["record_id"]]
                ),
              do: touch_message(query, text["record_id"])

        type when type in ["User", "Account"] ->
          table = if type == "User", do: "users", else: "accounts"

          query.("UPDATE #{table} SET updated_at=? WHERE id=?", [
            Chat.timestamp(),
            attachment["record_id"]
          ])

        _ ->
          :ok
      end
    end
  end

  defp touch_message(query, id) do
    query.("UPDATE messages SET updated_at=? WHERE id=?", [Chat.timestamp(), id])

    query.(
      "UPDATE rooms SET updated_at=? WHERE id IN (SELECT room_id FROM messages WHERE id=?)",
      [Chat.timestamp(), id]
    )
  end

  def analyze_later(blob) do
    metadata = Jason.decode!(blob["metadata"] || "{}")

    cond do
      metadata["analyzed"] ->
        :ok

      String.starts_with?(blob["content_type"] || "", "image/") ||
        String.starts_with?(blob["content_type"] || "", "video/") ||
          String.starts_with?(blob["content_type"] || "", "audio/") ->
        Jobs.enqueue("ActiveStorage::AnalyzeJob", [
          %{"_aj_globalid" => "gid://campfire/ActiveStorage::Blob/#{blob["id"]}"}
        ])

      true ->
        StorageMedia.analyze(blob)
    end
  end

  def atomic(type, id, name, input, update) do
    {:ok, prepared} = if input == :unchanged, do: {:ok, :unchanged}, else: prepare(input)

    result =
      DB.transaction(fn q ->
        record = update.(q)

        change =
          if prepared == :unchanged, do: :unchanged, else: change(q, type, id, name, prepared)

        {record, change}
      end)

    case result do
      {record, :unchanged} ->
        record

      {record, {:changed, old, new}} ->
        if old, do: purge_later(old)
        if new, do: analyze_later(new)
        record

      {:error, _} = error ->
        discard(prepared)
        error
    end
  end

  def discard(blob) when is_map(blob) do
    if !blob["id"], do: File.rm(Storage.path(blob["key"]))
    :ok
  end

  def discard(_), do: :ok

  defp change(q, type, id, name, prepared) do
    old =
      List.first(
        q.(
          "SELECT b.* FROM active_storage_attachments a JOIN active_storage_blobs b ON b.id=a.blob_id WHERE a.record_type=? AND a.record_id=? AND a.name=?",
          [type, id, name]
        )
      )

    if (is_nil(old) && is_nil(prepared)) || (old && prepared && old["id"] == prepared["id"]) do
      :unchanged
    else
      q.(
        "DELETE FROM active_storage_attachments WHERE record_type=? AND record_id=? AND name=?",
        [type, id, name]
      )

      new = if prepared, do: save(q, prepared, type, id, name)
      table = %{"User" => "users", "Account" => "accounts", "Message" => "messages"}[type]
      q.("UPDATE #{table} SET updated_at=? WHERE id=?", [Chat.timestamp(), id])
      {:changed, old, new}
    end
  end

  def replace(type, id, name, input) do
    with {:ok, prepared} <- prepare(input) do
      existing = find(type, id, name)

      if existing && prepared && existing["id"] == prepared["id"] do
        {:ok, existing}
      else
        result =
          DB.transaction(fn q ->
            q.(
              "DELETE FROM active_storage_attachments WHERE record_type=? AND record_id=? AND name=?",
              [type, id, name]
            )

            blob = if prepared, do: save(q, prepared, type, id, name)

            table =
              case type do
                "User" -> "users"
                "Account" -> "accounts"
                "Message" -> "messages"
              end

            q.("UPDATE #{table} SET updated_at=? WHERE id=?", [Chat.timestamp(), id])
            {:replaced, blob}
          end)

        case result do
          {:replaced, blob} ->
            if existing, do: purge_later(existing)
            if blob, do: analyze_later(blob)
            {:ok, blob}

          error ->
            error
        end
      end
    end
  end

  def purge_later(blob),
    do:
      Jobs.enqueue("ActiveStorage::PurgeJob", [
        %{"_aj_globalid" => "gid://campfire/ActiveStorage::Blob/#{blob["id"]}"}
      ])

  def purge(blob) do
    result =
      DB.transaction(fn q ->
        if q.("SELECT id FROM active_storage_attachments WHERE blob_id=? LIMIT 1", [blob["id"]]) !=
             [] do
          :attached
        else
          children =
            q.(
              "SELECT b.* FROM active_storage_blobs b JOIN active_storage_attachments a ON a.blob_id=b.id WHERE (a.record_type='ActiveStorage::Blob' AND a.record_id=?) OR (a.record_type='ActiveStorage::VariantRecord' AND a.record_id IN (SELECT id FROM active_storage_variant_records WHERE blob_id=?))",
              [blob["id"], blob["id"]]
            )

          q.(
            "DELETE FROM active_storage_attachments WHERE (record_type='ActiveStorage::Blob' AND record_id=?) OR (record_type='ActiveStorage::VariantRecord' AND record_id IN (SELECT id FROM active_storage_variant_records WHERE blob_id=?))",
            [blob["id"], blob["id"]]
          )

          q.("DELETE FROM active_storage_variant_records WHERE blob_id=?", [blob["id"]])
          q.("DELETE FROM active_storage_blobs WHERE id=?", [blob["id"]])
          {:purged, children}
        end
      end)

    case result do
      {:purged, children} ->
        File.rm(Storage.path(blob["key"]))
        Enum.each(children, &purge_later/1)
        :ok

      :attached ->
        :ok

      error ->
        error
    end
  end

  def process_message(message) do
    if blob = find("Message", message["id"], "attachment") do
      with {:ok, blob} <- StorageMedia.analyze(blob) do
        cond do
          Storage.variable?(blob) ->
            StorageMedia.process(blob, thumbnail(blob))

          String.starts_with?(blob["content_type"] || "", "video/") ->
            StorageMedia.process(blob, %{"hash" => [["format", %{"sym" => "webp"}]]})

          true ->
            :ok
        end
      end
    else
      :ok
    end
  end

  def thumbnail(blob) do
    format =
      if blob["content_type"] in ~w(image/png image/jpeg image/gif image/webp) do
        ext =
          Campfire.Filename.extension(blob["filename"])
          |> String.trim_leading(".")
          |> String.downcase()

        if ext in Mime.extensions(blob["content_type"]),
          do: ext,
          else: List.first(Mime.extensions(blob["content_type"]))
      else
        "png"
      end

    %{"hash" => [["format", %{"str" => format}], ["resize_to_limit", [1200, 800]]]}
  end
end
