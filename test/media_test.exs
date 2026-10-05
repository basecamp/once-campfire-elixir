defmodule Campfire.MediaTest do
  use ExUnit.Case, async: true
  alias Campfire.Media

  @vectors Jason.decode!(File.read!("vectors/storage.json"))
  @arm64_oracle Jason.decode!(File.read!("vectors/storage-arm64.json"))
  @arm64 String.starts_with?(to_string(:erlang.system_info(:system_architecture)), "aarch64")

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

          expected = expected_preview(@item["fixture"], @item["preview_image"]["blob"])
          bytes = File.read!(preview)
          assert byte_size(bytes) == expected["byte_size"]
          assert Base.encode64(:crypto.hash(:md5, bytes)) == expected["checksum"]

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
      expected = expected_blob(@variant["label"], @variant["blob"])
      assert byte_size(bytes) == expected["byte_size"]
      assert Base.encode64(:crypto.hash(:md5, bytes)) == expected["checksum"]
      metadata = Jason.decode!(@variant["blob"]["metadata"])

      assert {:ok, %{"width" => metadata["width"], "height" => metadata["height"]}} ==
               Media.image_metadata(output)
    end
  end

  test "invalid images have no image metadata" do
    assert {:ok, %{}} = Media.image_metadata("reference/test/fixtures/files/alpha-centuri.mov")
  end

  defp expected_preview(fixture, default) do
    if @arm64 and fixture == @arm64_oracle["fixture"], do: @arm64_oracle["preview"], else: default
  end

  defp expected_blob(label, default) do
    if @arm64, do: Map.get(@arm64_oracle["variants"], label, default), else: default
  end
end
