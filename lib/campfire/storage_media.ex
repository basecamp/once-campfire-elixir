defmodule Campfire.StorageMedia do
  alias Campfire.{Chat, DB, Filename, Jobs, Media, Rails, Storage}

  @types %{
    "jpg" => "image/jpeg",
    "jpeg" => "image/jpeg",
    "png" => "image/png",
    "webp" => "image/webp",
    "gif" => "image/gif",
    "tif" => "image/tiff",
    "tiff" => "image/tiff",
    "avif" => "image/avif",
    "heic" => "image/heic",
    "heif" => "image/heif"
  }

  def variation_key(%{"hash" => pairs}) do
    pairs = Enum.map(pairs, fn [key, value] -> {key, untyped(value)} end)
    Rails.sign_message("ActiveStorage", Storage.ordered_json(pairs), "variation")
  end

  def decode_variation(token) do
    with value when is_map(value) <- Rails.verify_message("ActiveStorage", token, "variation"),
         [encoded, _signature] <- String.split(token, "--"),
         {:ok, json} <- Base.decode64(encoded),
         {:ok, %Jason.OrderedObject{} = envelope} <- Jason.decode(json, objects: :ordered_objects) do
      rails =
        Enum.find_value(envelope.values, fn {key, value} -> if key == "_rails", do: value end)

      data = Enum.find_value(rails.values, fn {key, value} -> if key == "data", do: value end)
      {:ok, typed(data)}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  def process(blob, typed) do
    if String.starts_with?(blob["content_type"] || "", "video/") do
      with {:ok, preview} <- preview(blob), do: process(preview, typed)
    else
      case Storage.existing_variant(blob, typed) do
        nil -> transform(blob, typed)
        variant -> {:ok, variant}
      end
    end
  end

  defp preview(blob) do
    case Campfire.Attachments.find("ActiveStorage::Blob", blob["id"], "preview_image") do
      nil ->
        output =
          Path.join(
            System.tmp_dir!(),
            "preview-#{Campfire.Random.token(28, "0123456789abcdefghijklmnopqrstuvwxyz")}.jpg"
          )

        try do
          with :ok <- Media.preview(Storage.path(blob["key"]), output),
               {:ok, prepared} <-
                 Campfire.Attachments.prepare_bytes(
                   File.read!(output),
                   Filename.base(blob["filename"]) <> ".jpg",
                   "image/jpeg"
                 ) do
            result =
              DB.transaction(fn q ->
                case q.(
                       "SELECT b.* FROM active_storage_attachments a JOIN active_storage_blobs b ON b.id=a.blob_id WHERE a.record_type='ActiveStorage::Blob' AND a.record_id=? AND a.name='preview_image'",
                       [blob["id"]]
                     ) do
                  [existing] ->
                    {:existing, existing}

                  [] ->
                    {:created,
                     Campfire.Attachments.save(
                       q,
                       prepared,
                       "ActiveStorage::Blob",
                       blob["id"],
                       "preview_image"
                     )}
                end
              end)

            case result do
              {:created, image} ->
                Campfire.Attachments.analyze_later(image)
                {:ok, image}

              {:existing, image} ->
                File.rm(Storage.path(prepared["key"]))
                {:ok, image}

              error ->
                File.rm(Storage.path(prepared["key"]))
                error
            end
          end
        after
          File.rm(output)
        end

      image ->
        {:ok, image}
    end
  end

  def analyze(blob) do
    path = Storage.path(blob["key"])
    type = blob["content_type"] || ""

    result =
      cond do
        String.starts_with?(type, "image/") -> Media.image_metadata(path)
        String.starts_with?(type, "video/") -> Media.video_metadata(path)
        String.starts_with?(type, "audio/") -> Media.audio_metadata(path)
        true -> {:ok, %{}}
      end

    with {:ok, extracted} <- result do
      %Jason.OrderedObject{values: existing} =
        Jason.decode!(blob["metadata"] || "{}", objects: :ordered_objects)

      additions =
        for key <-
              ~w(width height duration angle display_aspect_ratio audio video bit_rate sample_rate tags),
            Map.has_key?(extracted, key),
            do: {key, extracted[key]}

      values =
        Enum.reduce(additions ++ [{"analyzed", true}], existing, fn {key, value}, pairs ->
          if List.keymember?(pairs, key, 0),
            do: List.keyreplace(pairs, key, 0, {key, value}),
            else: pairs ++ [{key, value}]
        end)

      metadata = %Jason.OrderedObject{values: values}

      updated =
        DB.transaction(fn query ->
          [updated] =
            query.("UPDATE active_storage_blobs SET metadata=? WHERE id=? RETURNING *", [
              Rails.json(metadata),
              blob["id"]
            ])

          Campfire.Attachments.touch_records(query, blob["id"])

          updated
        end)

      {:ok, updated}
    end
  end

  defp transform(blob, %{"hash" => entries} = typed) do
    values = Map.new(entries, fn [key, value] -> {key, untyped(value)} end)
    format = String.downcase(values["format"] || "png")
    type = @types[format]

    if Storage.variable?(blob) && type do
      key = Campfire.Random.token(28, "0123456789abcdefghijklmnopqrstuvwxyz")
      output = Path.join(System.tmp_dir!(), "#{key}.#{format}")

      try do
        result =
          Media.transform(
            Storage.path(blob["key"]),
            output,
            Enum.map(entries, fn [key, value] -> {key, untyped(value)} end)
          )

        with :ok <- result do
          persist_variant(blob, typed, output, key, format, type)
        end
      after
        File.rm(output)
      end
    else
      {:error, :unsupported_transformation}
    end
  end

  defp persist_variant(blob, typed, output, key, format, type) do
    bytes = File.read!(output)
    type = Campfire.Mime.identify(bytes, Filename.base(blob["filename"]) <> "." <> format, type)
    checksum = Base.encode64(:crypto.hash(:md5, bytes))
    digest = Base.encode64(:crypto.hash(:sha, Campfire.Marshal.dump(typed)))
    now = Chat.timestamp()
    destination = Storage.path(key)
    File.mkdir_p!(Path.dirname(destination))
    File.cp!(output, destination)

    result =
      DB.transaction(fn q ->
        existing =
          q.(
            "SELECT b.* FROM active_storage_variant_records v JOIN active_storage_attachments a ON a.record_type='ActiveStorage::VariantRecord' AND a.record_id=v.id AND a.name='image' JOIN active_storage_blobs b ON b.id=a.blob_id WHERE v.blob_id=? AND v.variation_digest=?",
            [blob["id"], digest]
          )

        case existing do
          [variant] ->
            {:existing, variant}

          [] ->
            [record] =
              q.(
                "INSERT INTO active_storage_variant_records (blob_id,variation_digest) VALUES (?,?) RETURNING *",
                [blob["id"], digest]
              )

            [variant] =
              q.(
                "INSERT INTO active_storage_blobs (key,filename,content_type,metadata,service_name,byte_size,checksum,created_at) VALUES (?,?,?,'{\"identified\":true}',?,?,?,?) RETURNING *",
                [
                  key,
                  Filename.base(blob["filename"]) <> "." <> format,
                  type,
                  blob["service_name"],
                  byte_size(bytes),
                  checksum,
                  now
                ]
              )

            q.(
              "INSERT INTO active_storage_attachments (name,record_type,record_id,blob_id,created_at) VALUES ('image','ActiveStorage::VariantRecord',?,?,?)",
              [record["id"], variant["id"], now]
            )

            {:created, variant}
        end
      end)

    case result do
      {:created, variant} ->
        Jobs.enqueue("ActiveStorage::AnalyzeJob", [
          %{"_aj_globalid" => "gid://campfire/ActiveStorage::Blob/#{variant["id"]}"}
        ])

        {:ok, variant}

      {:existing, variant} ->
        File.rm(destination)
        {:ok, variant}

      error ->
        File.rm(destination)
        error
    end
  end

  defp typed(%Jason.OrderedObject{values: values}),
    do: %{"hash" => Enum.map(values, fn {key, value} -> [key, typed(value)] end)}

  defp typed(value) when is_binary(value), do: %{"str" => value}
  defp typed(value) when is_list(value), do: Enum.map(value, &typed/1)
  defp typed(value), do: value

  defp untyped(%{"hash" => pairs}),
    do: %Jason.OrderedObject{
      values: Enum.map(pairs, fn [key, value] -> {key, untyped(value)} end)
    }

  defp untyped(%{"str" => value}), do: value
  defp untyped(%{"sym" => value}), do: value
  defp untyped(value) when is_list(value), do: Enum.map(value, &untyped/1)
  defp untyped(value), do: value
end
