defmodule Campfire.TransformationsTest do
  use ExUnit.Case, async: true

  @vectors for item <- Campfire.JSON.decode!(File.read!("vectors/transformations.json")),
               do: Map.new(item)
  for {item, index} <- Enum.with_index(@vectors) do
    @item item
    test "pinned Active Storage image transformation #{index}" do
      input = "reference/test/fixtures/files/" <> @item["fixture"]
      output = Path.join(System.tmp_dir!(), "transform-#{System.unique_integer([:positive])}.png")
      on_exit(fn -> File.rm(output) end)

      result =
        Campfire.Media.transform(input, output, Campfire.JSON.pairs(@item["transformations"]))

      if @item["error"] do
        assert match?({:error, _}, result)
      else
        assert result == :ok
        bytes = File.read!(output)
        assert byte_size(bytes) == @item["bytes"]
        assert Base.encode64(:crypto.hash(:md5, bytes)) == @item["checksum"]

        assert {:ok, %{"width" => @item["width"], "height" => @item["height"]}} ==
                 Campfire.Media.image_metadata(output)
      end
    end
  end
end
