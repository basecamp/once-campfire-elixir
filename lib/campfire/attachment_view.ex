defmodule Campfire.AttachmentView do
  alias Campfire.{Assets, Attachments, Filename, Storage, StorageMedia}

  def render(blob) do
    download = escape(Storage.blob_path(blob) <> "?disposition=attachment")
    filename = escape(Filename.sanitized(blob["filename"]))
    video? = String.starts_with?(blob["content_type"] || "", "video/")

    if Storage.variable?(blob) || video? do
      metadata = Jason.decode!(blob["metadata"] || "{}")
      {width, height} = dimensions(metadata)

      content =
        if video? do
          typed = %{"hash" => [["format", %{"sym" => "webp"}], ["resize_to_limit", [1200, 800]]]}

          ~s(<video src="#{escape(Storage.blob_path(blob))}" poster="#{escape(representation(blob, typed))}" controls="controls" preload="none" width="100%" height="100%" class="message__attachment"></video>)
        else
          image =
            ~s(<img width="#{number(width)}" height="#{number(height)}" class="message__attachment" loading="lazy" src="#{escape(representation(blob, Attachments.thumbnail(blob)))}" />)

          ~s(<a class="flex" data-lightbox-target="image" data-action="lightbox#open" data-lightbox-url-value="#{download}" href="#{escape(Storage.blob_path(blob))}">#{image}</a>)
        end

      if width && height do
        # Ruby's Integer division truncates; resized dimensions are Float values.
        half = if is_integer(width), do: div(width, 2), else: width / 2

        ~s(<div class="max-inline-size center flex overflow-clip" style="width: #{number(half)}px; aspect-ratio: #{number(width / height)};">#{content}</div>)
      else
        ~s(<div class="max-inline-size center overflow-clip">#{content}</div>)
      end
    else
      ~s(<div class="flex-inline align-center gap-half"><img class="colorize--black" aria-hidden="true" src="#{Assets.path("common-file-text.svg")}" width="22" height="22" /><span>#{filename}</span><a class="btn message__action-btn hide-in-ios-pwa" style="--width: auto;" href="#{download}"><img aria-hidden="true" src="#{Assets.path("download.svg")}" width="20" height="20" /><span class="for-screen-reader">Download #{filename}</span></a><button class="btn message__action-btn" style="--width: auto;" data-controller="web-share" data-action="web-share#share" data-web-share-files-value="#{download}"><img aria-hidden="true" src="#{Assets.path("share.svg")}" width="20" height="20" /><span class="for-screen-reader">Share #{filename}</span></button></div>)
    end
  end

  def representation(blob, typed) do
    "/rails/active_storage/representations/redirect/" <>
      Filename.escape_segment(Storage.signed_id(blob)) <>
      "/" <>
      Filename.escape_segment(StorageMedia.variation_key(typed)) <>
      "/" <> Filename.escape_path(Filename.sanitized(blob["filename"]))
  end

  defp dimensions(%{"width" => width, "height" => height}) do
    if width <= 1200 && height <= 800 do
      {width, height}
    else
      scale = min(1200 / width, 800 / height)
      {width * scale, height * scale}
    end
  end

  defp dimensions(_), do: {nil, nil}
  defp number(nil), do: ""

  defp number(value) when is_float(value),
    do: :erlang.float_to_binary(value, [:short]) |> expand_float()

  defp number(value), do: to_string(value)

  defp expand_float(value) do
    if String.contains?(value, "e") do
      [mantissa, exponent] = String.split(value, "e")
      exp = String.to_integer(exponent)

      if exp in -4..15 do
        negative = String.starts_with?(mantissa, "-")
        [whole, fraction] = String.split(String.trim_leading(mantissa, "-"), ".")
        digits = whole <> fraction
        position = byte_size(whole) + exp

        expanded =
          cond do
            position <= 0 ->
              "0." <> String.duplicate("0", -position) <> digits

            position >= byte_size(digits) ->
              digits <> String.duplicate("0", position - byte_size(digits)) <> ".0"

            true ->
              String.slice(digits, 0, position) <>
                "." <> String.slice(digits, position, byte_size(digits))
          end

        if negative, do: "-" <> expanded, else: expanded
      else
        value
      end
    else
      value
    end
  end

  defp escape(value), do: Assets.html_escape(value)
end
