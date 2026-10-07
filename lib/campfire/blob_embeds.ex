defmodule Campfire.BlobEmbeds do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  alias Campfire.{Attachments, DB, Rails, RichText}

  def resolve(attrs) do
    with token when is_binary(token) <- Map.new(attrs)["sgid"],
         gid when is_binary(gid) <- Rails.verify_message("signed_global_ids", token, "attachable"),
         %URI{scheme: "gid", path: path} <- URI.parse(gid),
         [_, id] <- Regex.run(~r/\A\/ActiveStorage::Blob\/([0-9]+)\z/, path) do
      DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [String.to_integer(id)])
    else
      _ -> nil
    end
  end

  def render(blob, attrs) do
    data = Map.new(attrs)

    preview =
      Campfire.Storage.variable?(blob) ||
        String.starts_with?(blob["content_type"] || "", "video/")

    kind = if preview, do: "preview", else: "file"
    extension = Campfire.Filename.extension(blob["filename"]) |> String.trim_leading(".")

    image =
      if preview do
        typed =
          if Campfire.Storage.variable?(blob),
            do: Attachments.thumbnail(blob),
            else: %{"hash" => [["resize_to_limit", [1200, 800]]]}

        size = if Process.get(:campfire_blob_gallery, false), do: [800, 600], else: [1024, 768]

        typed =
          Map.update!(typed, "hash", fn entries ->
            Enum.map(entries, fn
              ["resize_to_limit", _] -> ["resize_to_limit", size]
              entry -> entry
            end)
          end)

        base =
          Process.get(:campfire_request_base, System.get_env("APP_URL", "http://example.org"))

        ~s(    <img src="#{Campfire.Assets.html_escape(base <> Campfire.AttachmentView.representation(blob, typed))}">\n)
      else
        ""
      end

    caption =
      if Map.has_key?(data, "caption") do
        "      " <> Campfire.Assets.html_escape(data["caption"]) <> "\n"
      else
        ~s(      <span class="attachment__name">#{Campfire.Assets.html_escape(blob["filename"])}</span>\n      <span class="attachment__size">#{human_size(blob["byte_size"])}</span>\n)
      end

    ~s(<figure class="attachment attachment--#{kind} attachment--#{Campfire.Assets.html_escape(extension)}">\n#{image}\n  <figcaption class="attachment__caption">\n#{caption}  </figcaption>\n</figure>)
  end

  defp human_size(1), do: "1 Byte"
  defp human_size(bytes) when bytes < 1024, do: "#{bytes} Bytes"

  defp human_size(bytes) do
    power = min(trunc(:math.log(bytes) / :math.log(1024)), 5)
    value = bytes / :math.pow(1024, power)
    places = max(2 - trunc(:math.log10(value)), 0)
    number = :erlang.float_to_binary(Float.round(value, places), decimals: places)

    number =
      if places > 0,
        do: number |> String.trim_trailing("0") |> String.trim_trailing("."),
        else: number

    number <> " " <> Enum.at(~w(Bytes KB MB GB TB PB), power)
  end

  def blobs(body) do
    body
    |> RichText.parse()
    |> Floki.find("action-text-attachment")
    |> Enum.map(fn {_, attrs, _} -> resolve(attrs) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1["id"])
  end

  def sync(query, text_id, blobs) do
    old =
      query.(
        "SELECT b.* FROM active_storage_blobs b JOIN active_storage_attachments a ON a.blob_id=b.id WHERE a.record_type='ActionText::RichText' AND a.record_id=? AND a.name='embeds'",
        [text_id]
      )

    added = Enum.reject(blobs, fn blob -> Enum.any?(old, &(&1["id"] == blob["id"])) end)
    removed = Enum.reject(old, fn blob -> Enum.any?(blobs, &(&1["id"] == blob["id"])) end)

    for blob <- removed,
        do:
          query.(
            "DELETE FROM active_storage_attachments WHERE record_type='ActionText::RichText' AND record_id=? AND blob_id=? AND name='embeds'",
            [text_id, blob["id"]]
          )

    for blob <- added,
        do: Attachments.save(query, blob, "ActionText::RichText", text_id, "embeds")

    {added, removed}
  end

  def committed({added, removed}) do
    Enum.each(removed, &Attachments.purge_later/1)
    Enum.each(added, &Attachments.analyze_later/1)
  end
end
