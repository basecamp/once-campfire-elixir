Code.require_file("support/media_gate.ex", __DIR__)
Code.require_file("support/media_variants.ex", __DIR__)

defmodule Campfire.MediaPixelsTest do
  use ExUnit.Case, async: true

  alias Campfire.{Media, MediaGate, MediaVariants}

  for {item, variant} <- MediaGate.storage_cases() do
    @item item
    @variant variant

    if MediaGate.lossy?(item, variant) do
      @tag :pinned_libvips
    end

    test "decoded pixels of media pipeline #{variant["label"]}" do
      directory = Path.join(System.tmp_dir!(), "pixels-#{System.unique_integer([:positive])}")
      File.mkdir_p!(directory)
      on_exit(fn -> File.rm_rf(directory) end)

      assert {:ok, output, preview} = MediaVariants.run_variant(@item, @variant, directory)

      if preview do
        assert_pixels(preview, preview_expectation(@item))
      end

      assert_pixels(output, variant_expectation(@variant))

      metadata = Jason.decode!(@variant["blob"]["metadata"])

      assert {:ok, %{"width" => metadata["width"], "height" => metadata["height"]}} ==
               Media.image_metadata(output)
    end
  end

  test "invalid images have no image metadata" do
    assert {:ok, %{}} == Media.image_metadata("reference/test/fixtures/files/alpha-centuri.mov")
  end

  defp assert_pixels(path, %{"pixels" => expected}) do
    assert {:ok, digest} = MediaGate.digest(path)
    assert digest == expected
  end

  defp assert_pixels(_path, _expectation), do: :ok

  defp variant_expectation(variant), do: arch_expectation("variants")[variant["label"]] || variant

  defp preview_expectation(item) do
    arch_expectation("preview") || item["preview_image"]["blob"]
  end

  defp arch_expectation(key) do
    if arm64?(), do: Map.new(Jason.decode!(File.read!("vectors/storage-arm64.json")))[key]
  end

  defp arm64?,
    do: String.starts_with?(to_string(:erlang.system_info(:system_architecture)), "aarch64")
end
