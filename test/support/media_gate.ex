defmodule Campfire.MediaGate do
  @moduledoc """
  Case enumeration and pixel digests shared by the media gates and their recorder.

  The byte vectors only hold on the pinned libvips, because resampling changed between 8.16 and
  8.18. Pixels do not: a digest over the decoded image catches pipeline mistakes on any version,
  which is what lets the same cases run on a host whose libvips differs from the reference.
  """

  alias Vix.Vips.Image

  @fixtures "reference/test/fixtures/files/"

  def transformation_cases do
    for item <-
          Jason.decode!(File.read!("vectors/transformations.json"), objects: :ordered_objects),
        do: Map.new(item.values)
  end

  def storage_cases do
    vectors = Jason.decode!(File.read!("vectors/storage.json"))

    for item <- vectors["messages"] ++ vectors["avatars"] ++ vectors["logos"],
        variant <- item["variants"] || [],
        File.regular?(@fixtures <> item["fixture"]),
        do: {item, variant}
  end

  @resampler_sensitive ["resize_to_fill", "resize_and_pad", "resize_to_cover"]
  @lossy ["webp", "jpg", "jpeg", "avif", "heic"]

  @doc """
  Whether libvips changed the resampled pixels between 8.16 and 8.18 for this case: cropping,
  padding and omitted dimensions go through a different path and only agree on the pinned build.
  """
  def resampler_sensitive?(transformations) do
    Enum.any?(transformations, fn {name, value} ->
      name in @resampler_sensitive or
        (name in ["resize_to_limit", "resize_to_fit"] and is_list(value) and
           Enum.any?(value, &is_nil/1))
    end)
  end

  @doc "Whether the variant's output is a lossy format, whose decoded pixels follow the encoder."
  def lossy?(item, variant) do
    entries =
      variant["transformations_typed"]["hash"] |> Map.new(fn [key, value] -> {key, value} end)

    format = entries["format"]["str"] || entries["format"]["sym"]
    item["declared_type"] == "video/quicktime" or format in @lossy
  end

  @doc """
  Digest over the decoded image: dimensions, bands, band format and the raw pixels.

  Encoding differs between libvips versions, pixels do not, so this is the version-independent
  half of the media contract.
  """
  def digest(path) do
    with {:ok, image} <- Image.new_from_file(path),
         {:ok, raw} <- Image.write_to_buffer(image, ".raw"),
         {:ok, width} <- Image.header_value(image, "width"),
         {:ok, height} <- Image.header_value(image, "height"),
         {:ok, bands} <- Image.header_value(image, "bands"),
         {:ok, format} <- Image.header_value(image, "format") do
      {:ok,
       :crypto.hash(:md5, ["#{width}x#{height}x#{bands}x#{format}:", raw]) |> Base.encode64()}
    end
  end
end
