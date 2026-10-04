defmodule Campfire.MediaTest do
  use ExUnit.Case, async: true
  alias Campfire.Media

  @vectors Jason.decode!(File.read!("vectors/storage.json"))
  for item <- @vectors["messages"] ++ @vectors["avatars"] ++ @vectors["logos"],
      variant <- item["variants"] || [],
      File.regular?("reference/test/fixtures/files/" <> item["fixture"]) do
    @item item
    @variant variant
    test "byte-identical media pipeline #{variant["label"]}" do
      input = "reference/test/fixtures/files/" <> @item["fixture"]

      input =
        if @item["declared_type"] == "video/quicktime" do
          preview =
            Path.join(System.tmp_dir!(), "preview-#{System.unique_integer([:positive])}.jpg")

          on_exit(fn -> File.rm(preview) end)
          assert :ok = Media.preview(input, preview)
          preview
        else
          input
        end

      entries =
        @variant["transformations_typed"]["hash"] |> Map.new(fn [key, value] -> {key, value} end)

      format = entries["format"]["str"] || entries["format"]["sym"]
      [width, height] = entries["resize_to_limit"] || [10_000_000, 10_000_000]

      output =
        Path.join(System.tmp_dir!(), "media-#{System.unique_integer([:positive])}.#{format}")

      on_exit(fn -> File.rm(output) end)

      if entries["resize_to_limit"] do
        assert :ok = Media.resize(input, output, width, height)
      else
        assert :ok = Media.convert(input, output)
      end

      bytes = File.read!(output)
      assert byte_size(bytes) == @variant["blob"]["byte_size"]
      assert Base.encode64(:crypto.hash(:md5, bytes)) == @variant["blob"]["checksum"]
      metadata = Jason.decode!(@variant["blob"]["metadata"])

      assert {:ok, %{"width" => metadata["width"], "height" => metadata["height"]}} ==
               Media.image_metadata(output)
    end
  end

  test "invalid images have no image metadata" do
    assert {:ok, %{}} = Media.image_metadata("reference/test/fixtures/files/alpha-centuri.mov")
  end
end
