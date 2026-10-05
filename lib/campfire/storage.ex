defmodule Campfire.Storage do
  import Plug.Conn
  alias Campfire.{Auth, Chat, Clock, DB, Filename, Rack, Rails}
  @prefix "/rails/active_storage"
  @binary_types ~w(text/html image/svg+xml application/postscript application/x-shockwave-flash text/xml application/xml application/xhtml+xml application/mathml+xml text/cache-manifest)
  @inline_types ~w(image/webp image/avif image/png image/gif image/jpeg image/tiff image/bmp image/vnd.adobe.photoshop image/vnd.microsoft.icon application/pdf)

  def variable?(blob),
    do:
      blob &&
        blob["content_type"] in ~w(image/png image/gif image/jpeg image/tiff image/webp image/avif image/heic image/heif)

  def existing_variant(blob, typed) do
    digest = :crypto.hash(:sha, Campfire.Marshal.dump(typed)) |> Base.encode64()

    DB.one(
      "SELECT b.* FROM active_storage_variant_records v JOIN active_storage_attachments a ON a.record_type='ActiveStorage::VariantRecord' AND a.record_id=v.id AND a.name='image' JOIN active_storage_blobs b ON b.id=a.blob_id WHERE v.blob_id=? AND v.variation_digest=?",
      [blob["id"], digest]
    )
  end

  def path(key) do
    root = System.get_env("STORAGE_PATH", "var/files") |> Path.expand()

    if is_binary(key) && Regex.match?(~r/\A[a-zA-Z0-9_-]{4,}\z/, key) do
      Path.join([root, String.slice(key, 0, 2), String.slice(key, 2, 2), key])
    else
      raise ArgumentError, "invalid storage key"
    end
  end

  def signed_id(blob), do: Rails.sign_message("ActiveStorage", Rails.json(blob["id"]), "blob_id")

  def blob_path(blob),
    do:
      @prefix <>
        "/blobs/redirect/" <>
        Filename.escape_segment(signed_id(blob)) <>
        "/" <> Filename.escape_path(Filename.sanitized(blob["filename"]))

  def disk_path(blob, disposition \\ "inline", expires \\ nil) do
    type = blob["content_type"]

    disposition =
      if type in @inline_types && type not in @binary_types, do: disposition, else: "attachment"

    type = if type in @binary_types, do: "application/octet-stream", else: type

    fields = [
      {"key", blob["key"]},
      {"disposition",
       Filename.disposition(
         if(disposition == "attachment", do: "attachment", else: "inline"),
         blob["filename"]
       )},
      {"content_type", type},
      {"service_name", blob["service_name"]}
    ]

    encoded = Rails.sign_message("ActiveStorage", ordered_json(fields), "blob_key", expires)

    @prefix <>
      "/disk/" <>
      Filename.escape_segment(encoded) <>
      "/" <> Filename.escape_path(Filename.sanitized(blob["filename"]))
  end

  def redirect_blob(conn, id) do
    with blob_id when is_integer(blob_id) <- Rails.verify_message("ActiveStorage", id, "blob_id"),
         blob when is_map(blob) <-
           DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [blob_id]) do
      expires =
        DateTime.add(Clock.now(), 300)
        |> DateTime.truncate(:millisecond)
        |> then(fn date -> %{date | microsecond: {elem(date.microsecond, 0), 3}} end)
        |> DateTime.to_iso8601()

      conn
      |> put_resp_header("cache-control", "max-age=300, private")
      |> Auth.redirect(disk_path(blob, conn.params["disposition"] || "inline", expires))
    else
      nil -> head(conn, 404)
      _ -> head(conn, 404)
    end
  end

  def representation(conn, id, variation_key, proxy? \\ false) do
    with blob_id when is_integer(blob_id) <- Rails.verify_message("ActiveStorage", id, "blob_id"),
         blob when is_map(blob) <-
           DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [blob_id]),
         {:ok, typed} <- Campfire.StorageMedia.decode_variation(variation_key),
         {:ok, variant} <- Campfire.StorageMedia.process(blob, typed) do
      if proxy?,
        do: proxy(conn, signed_id(variant)),
        else: redirect_blob(conn, signed_id(variant))
    else
      nil -> head(conn, 404)
      {:error, :invalid_signature} -> head(conn, 404)
      {:error, _} -> Campfire.HttpResponse.error(conn, 500)
      _ -> head(conn, 404)
    end
  end

  def disk(conn, id) do
    conn = put_resp_header(conn, "cache-control", "max-age=3600, public")

    case Rails.verify_message("ActiveStorage", id, "blob_key") do
      %{
        "key" => key,
        "disposition" => disposition,
        "content_type" => type,
        "service_name" => "local"
      } ->
        file = path(key)

        case File.stat(file, time: :posix) do
          {:ok, stat} -> serve_disk(conn, file, stat, type, disposition)
          {:error, _} -> head(conn, 404)
        end

      _ ->
        head(conn, 404)
    end
  rescue
    ArgumentError -> head(conn, 404)
  end

  defp serve_disk(conn, file, stat, type, disposition) do
    modified = DateTime.from_unix!(stat.mtime) |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")

    conn =
      conn
      |> put_resp_header("content-type", type || "application/octet-stream")
      |> put_resp_header("content-disposition", disposition)

    if List.first(get_req_header(conn, "if-modified-since")) == modified do
      send_resp(conn, 304, "")
    else
      conn = put_resp_header(conn, "last-modified", modified)

      case Rack.ranges(List.first(get_req_header(conn, "range")), stat.size) do
        nil ->
          send_file(conn, 200, file)

        [] ->
          conn
          |> put_resp_header("content-range", "bytes */#{stat.size}")
          |> send_resp(416, "Byte range unsatisfiable\n")

        [[start, finish]] ->
          conn
          |> put_resp_header("content-range", "bytes #{start}-#{finish}/#{stat.size}")
          |> send_file(206, file, start, finish - start + 1)

        ranges ->
          body =
            for [start, finish] <- ranges do
              "\r\n--AaB03x\r\ncontent-type: text/plain\r\ncontent-range: bytes #{start}-#{finish}/#{stat.size}\r\n\r\n" <>
                read_range(file, start, finish - start + 1)
            end

          send_resp(conn, 206, IO.iodata_to_binary([body, "\r\n--AaB03x--\r\n"]))
      end
    end
  end

  def proxy(conn, id) do
    with blob_id when is_integer(blob_id) <- Rails.verify_message("ActiveStorage", id, "blob_id"),
         blob when is_map(blob) <-
           DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [blob_id]) do
      type =
        if blob["content_type"] in @binary_types,
          do: "application/octet-stream",
          else: blob["content_type"] || "application/octet-stream"

      disposition =
        if blob["content_type"] in @inline_types && blob["content_type"] not in @binary_types,
          do: conn.params["disposition"] || "inline",
          else: "attachment"

      conn =
        conn
        |> put_resp_header("content-type", type)
        |> put_resp_header(
          "content-disposition",
          Filename.disposition(disposition, blob["filename"])
        )
        |> put_resp_header("accept-ranges", "bytes")

      file = path(blob["key"])

      if File.regular?(file) do
        range = List.first(get_req_header(conn, "range"))

        if is_nil(range) || range == "" do
          conn
          |> put_resp_header("cache-control", "max-age=3155695200, public, immutable")
          |> send_file(200, file)
        else
          case Rack.ranges(range, blob["byte_size"]) do
            nil ->
              head(conn, 416)

            [] ->
              head(conn, 416)

            [[start, finish]] ->
              conn
              |> put_resp_header(
                "content-range",
                "bytes #{start}-#{finish}/#{blob["byte_size"]}"
              )
              |> send_file(206, file, start, finish - start + 1)

            ranges ->
              boundary = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

              body =
                for [start, finish] <- ranges do
                  "\r\n--#{boundary}\r\nContent-Type: #{type}\r\nContent-Range: bytes #{start}-#{finish}/#{blob["byte_size"]}\r\n\r\n" <>
                    read_range(file, start, finish - start + 1)
                end

              conn
              |> put_resp_header("content-type", "multipart/byteranges; boundary=#{boundary}")
              |> send_resp(206, IO.iodata_to_binary([body, "\r\n--#{boundary}--\r\n"]))
          end
        end
      else
        conn |> put_resp_header("cache-control", "no-cache") |> head(404)
      end
    else
      _ -> head(conn, 404)
    end
  end

  def direct_upload(conn) do
    {conn, _user, session} = Auth.session_lookup(conn)

    cond do
      !Auth.csrf_valid?(conn, conn.params) ->
        Campfire.HttpResponse.error(conn, 422)

      !session ->
        head(conn, 401)

      true ->
        attrs = Campfire.Params.required(conn.params, "blob")

        if Chat.present?(attrs["filename"]) && Chat.present?(attrs["checksum"]) &&
             !is_nil(attrs["byte_size"]) do
          now = Chat.timestamp()
          key = Campfire.Random.token(28, "0123456789abcdefghijklmnopqrstuvwxyz")
          type = attrs["content_type"]
          size = Chat.integer(attrs["byte_size"])
          metadata = attrs["metadata"] || %{}

          case DB.query(
                 "INSERT INTO active_storage_blobs (key,filename,content_type,metadata,service_name,byte_size,checksum,created_at) VALUES (?,?,?,?,'local',?,?,?) RETURNING *",
                 [
                   key,
                   attrs["filename"],
                   type,
                   Rails.json(metadata),
                   size,
                   attrs["checksum"],
                   now
                 ]
               ) do
            [blob] ->
              token =
                upload_token(
                  blob,
                  DateTime.add(Clock.now(), 300)
                  |> DateTime.truncate(:millisecond)
                  |> then(fn date -> %{date | microsecond: {elem(date.microsecond, 0), 3}} end)
                  |> DateTime.to_iso8601()
                )

              response =
                blob
                |> Map.put("created_at", String.replace(now, " ", "T") <> ".000Z")
                |> Map.put("metadata", metadata)
                |> Map.put(
                  "attachable_sgid",
                  Rails.attachable_sgid("ActiveStorage::Blob", blob["id"])
                )
                |> Map.put("signed_id", signed_id(blob))
                |> Map.put("direct_upload", %{
                  "url" =>
                    Auth.base(conn) <> @prefix <> "/disk/" <> Filename.escape_segment(token),
                  "headers" => %{"Content-Type" => type}
                })

              conn
              |> put_resp_header("content-type", "application/json; charset=utf-8")
              |> send_resp(200, Rails.json(response))

            _ ->
              head(conn, 422)
          end
        else
          head(conn, 422)
        end
    end
  end

  def upload_token(blob, expires) do
    Rails.sign_message(
      "ActiveStorage",
      ordered_json([
        {"key", blob["key"]},
        {"content_type", blob["content_type"]},
        {"content_length", blob["byte_size"]},
        {"checksum", blob["checksum"]},
        {"service_name", blob["service_name"]}
      ]),
      "blob_token",
      expires
    )
  end

  def upload(conn, id) do
    {conn, _user, session} = Auth.session_lookup(conn)

    if session do
      case Rails.verify_message("ActiveStorage", id, "blob_token") do
        %{
          "key" => key,
          "content_type" => type,
          "content_length" => size,
          "checksum" => checksum,
          "service_name" => "local"
        } ->
          content_type =
            get_req_header(conn, "content-type")
            |> List.first()
            |> then(fn v -> if v, do: v |> String.split(";") |> hd() |> String.downcase() end)

          content_length =
            get_req_header(conn, "content-length") |> List.first() |> Chat.integer()

          if content_type == type && content_length == size do
            {:ok, body, conn} = Campfire.Body.read_all(conn)
            file = path(key)
            File.mkdir_p!(Path.dirname(file))
            File.write!(file, body)

            if byte_size(body) == size && Base.encode64(:crypto.hash(:md5, body)) == checksum do
              send_resp(conn, 204, "")
            else
              File.rm(file)
              head(conn, 422)
            end
          else
            head(conn, 422)
          end

        _ ->
          head(conn, 404)
      end
    else
      head(conn, 401)
    end
  rescue
    ArgumentError -> head(conn, 404)
  end

  def ordered_json(fields),
    do:
      "{" <>
        Enum.map_join(fields, ",", fn {key, value} ->
          Rails.json(key) <>
            ":" <>
            case value do
              {:raw, json} -> json
              _ -> Rails.json(value)
            end
        end) <> "}"

  defp read_range(file, start, length) do
    {:ok, io} = :file.open(String.to_charlist(file), [:read, :binary, :raw])

    try do
      {:ok, bytes} = :file.pread(io, start, length)
      bytes
    after
      :file.close(io)
    end
  end

  defp head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")
end
