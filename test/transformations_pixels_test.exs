Code.require_file("support/media_gate.ex", __DIR__)

defmodule Campfire.TransformationsPixelsTest do
  use ExUnit.Case, async: true

  alias Campfire.MediaGate

  for {item, index} <- Enum.with_index(Campfire.MediaGate.transformation_cases()) do
    @item item

    if MediaGate.resampler_sensitive?(item["transformations"].values) do
      @tag :pinned_libvips
    end

    test "decoded pixels of transformation #{index}" do
      input = "reference/test/fixtures/files/" <> @item["fixture"]
      output = Path.join(System.tmp_dir!(), "pixels-#{System.unique_integer([:positive])}.png")
      on_exit(fn -> File.rm(output) end)
      result = Campfire.Media.transform(input, output, @item["transformations"].values)

      if @item["error"] do
        assert match?({:error, _}, result)
      else
        assert result == :ok
        assert {:ok, digest} = Campfire.MediaGate.digest(output)
        assert digest == @item["pixels"]

        assert {:ok, %{"width" => @item["width"], "height" => @item["height"]}} ==
                 Campfire.Media.image_metadata(output)
      end
    end
  end
end
