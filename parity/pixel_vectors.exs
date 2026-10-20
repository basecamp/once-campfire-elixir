Code.require_file("../test/support/media_gate.ex", __DIR__)
Code.require_file("../test/support/media_variants.ex", __DIR__)

defmodule Campfire.PixelVectors do
  @moduledoc """
  Records the pixel digests the version-independent media gates compare against.

  Run it in the pinned toolchain (`bin/mix run parity/pixel_vectors.exs`): at that version the
  pipeline reproduces the reference bytes exactly, so its decoded pixels are the reference's.
  Arch-specific expectations go to storage-arm64.json the same way the byte oracles do.
  """

  alias Campfire.{MediaGate, MediaVariants}

  def run do
    record_transformations()
    if arm64?(), do: record_arm64_storage()
  end

  defp record_transformations do
    directory = directory()
    items = decode("vectors/transformations.json")

    recorded =
      Enum.map(items, fn item ->
        fields = Map.new(item.values)

        if fields["error"] do
          item
        else
          output = Path.join(directory, "t-#{System.unique_integer([:positive])}.png")

          :ok =
            Campfire.Media.transform(
              fixture_path(fields),
              output,
              fields["transformations"].values
            )

          {:ok, digest} = MediaGate.digest(output)
          File.rm(output)
          put(item, "pixels", digest)
        end
      end)

    write("vectors/transformations.json", recorded)
  end

  defp record_arm64_storage do
    directory = directory()
    oracle = decode("vectors/storage-arm64.json")
    fields = Map.new(oracle.values)

    variants =
      Enum.map(fields["variants"].values, fn {label, blob} ->
        {label, put(blob, "pixels", variant_pixels(oracle, label, directory))}
      end)

    recorded =
      oracle
      |> put("variants", %Jason.OrderedObject{values: variants})
      |> put("preview", put(fields["preview"], "pixels", preview_pixels(directory)))

    write("vectors/storage-arm64.json", recorded)
  end

  defp variant_pixels(oracle, label, directory) do
    fields = Map.new(oracle.values)
    fixture = fields["fixture"]

    {item, variant} =
      MediaGate.storage_cases()
      |> Enum.find(fn {item, variant} ->
        variant["label"] == label and item["fixture"] == fixture
      end)

    {:ok, output, _preview} = MediaVariants.run_variant(item, variant, directory)
    {:ok, digest} = MediaGate.digest(output)
    File.rm(output)
    digest
  end

  defp preview_pixels(directory) do
    fields = Map.new(decode("vectors/storage-arm64.json").values)
    input = "reference/test/fixtures/files/" <> fields["fixture"]
    preview = Path.join(directory, "preview-#{System.unique_integer([:positive])}.jpg")
    :ok = Campfire.Media.preview(input, preview)
    {:ok, digest} = MediaGate.digest(preview)
    File.rm(preview)
    digest
  end

  defp fixture_path(fields), do: "reference/test/fixtures/files/" <> fields["fixture"]

  defp put(%Jason.OrderedObject{values: values}, key, value) do
    %Jason.OrderedObject{values: List.keystore(values, key, 0, {key, value})}
  end

  defp decode(path), do: Jason.decode!(File.read!(path), objects: :ordered_objects)
  # Matches `json.dump(indent=2)`, which is how the oracle scripts write these files, so
  # recording a digest only adds lines.
  defp write(path, value), do: File.write!(path, render(value, 0) <> "\n")

  defp render(%Jason.OrderedObject{values: []}, _indent), do: "{}"

  defp render(%Jason.OrderedObject{values: values}, indent) do
    inner =
      Enum.map_join(values, ",\n", fn {key, value} ->
        pad(indent + 2) <> Jason.encode!(key) <> ": " <> render(value, indent + 2)
      end)

    "{\n" <> inner <> "\n" <> pad(indent) <> "}"
  end

  defp render([], _indent), do: "[]"

  defp render(list, indent) when is_list(list) do
    inner =
      Enum.map_join(list, ",\n", fn value -> pad(indent + 2) <> render(value, indent + 2) end)

    "[\n" <> inner <> "\n" <> pad(indent) <> "]"
  end

  defp render(value, _indent), do: Jason.encode!(value)

  defp pad(indent), do: String.duplicate(" ", indent)

  defp directory do
    path = Path.join(System.tmp_dir!(), "pixel-vectors-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end

  defp arm64?,
    do: String.starts_with?(to_string(:erlang.system_info(:system_architecture)), "aarch64")
end

Campfire.PixelVectors.run()
