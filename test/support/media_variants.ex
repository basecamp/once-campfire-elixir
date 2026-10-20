defmodule Campfire.MediaVariants do
  @moduledoc """
  Runs one stored Active Storage variant the way the byte gate does, for pixel comparison.

  Shared by the pixel test and the recorder so both exercise exactly the same pipeline.
  """

  alias Campfire.Media

  @fixtures "reference/test/fixtures/files/"

  def run_variant(item, variant, directory) do
    with {:ok, input, preview} <- prepare_input(item, directory),
         {:ok, output} <- transform(input, variant, directory) do
      {:ok, output, preview}
    end
  end

  defp prepare_input(%{"declared_type" => "video/quicktime"} = item, directory) do
    preview = Path.join(directory, "preview-#{System.unique_integer([:positive])}.jpg")

    case Media.preview(@fixtures <> item["fixture"], preview) do
      :ok -> {:ok, preview, preview}
      error -> error
    end
  end

  defp prepare_input(item, _directory), do: {:ok, @fixtures <> item["fixture"], nil}

  defp transform(input, variant, directory) do
    entries =
      variant["transformations_typed"]["hash"] |> Map.new(fn [key, value] -> {key, value} end)

    format = entries["format"]["str"] || entries["format"]["sym"]
    output = Path.join(directory, "variant-#{System.unique_integer([:positive])}.#{format}")

    result =
      case entries["resize_to_limit"] do
        [width, height] -> Media.resize(input, output, width, height)
        _ -> Media.convert(input, output)
      end

    case result do
      :ok -> {:ok, output}
      error -> error
    end
  end
end
