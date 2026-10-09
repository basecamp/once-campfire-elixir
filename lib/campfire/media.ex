defmodule Campfire.Media do
  @moduledoc "Image and video processing through the same libvips and FFmpeg pipelines as Active Storage."

  def image_metadata(path) do
    case run("campfire-vips", ["analyze", Path.expand(path)]) do
      {:ok, json} -> Jason.decode(json)
      error -> error
    end
  end

  def resize(input, output, width, height)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    case run("campfire-vips", [
           "resize",
           Path.expand(input),
           Path.expand(output),
           to_string(width),
           to_string(height)
         ]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def convert(input, output) do
    case run("campfire-vips", ["convert", Path.expand(input), Path.expand(output)]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def transform(input, output, entries) do
    arguments =
      Enum.flat_map(entries, fn {name, value} ->
        if name in ["format", "convert"] || value in [nil, false, "", []] || value == %{} do
          []
        else
          # An object (a list of pairs) is a single value, like a map.
          values =
            case value do
              [{_, _} | _] -> [value]
              list when is_list(list) -> list
              _ -> [value]
            end

          {positional, keywords} =
            case List.last(values) do
              [{_, _} | _] = pairs -> {Enum.drop(values, -1), pairs}
              map when is_map(map) -> {Enum.drop(values, -1), Map.to_list(map)}
              _ -> {values, []}
            end

          positional =
            if name in ["resize_to_limit", "resize_to_fit"],
              do: Enum.map(positional, &(&1 || 10_000_000)),
              else: positional

          [name, to_string(length(positional))] ++
            Enum.map(positional, &argument/1) ++
            [to_string(length(keywords))] ++
            Enum.flat_map(keywords, fn {key, value} -> [key, argument(value)] end)
        end
      end)

    format =
      Enum.find_value(entries, fn {key, value} ->
        if key == "convert" && value not in [nil, false, "", []], do: value
      end)

    destination = if is_binary(format), do: output <> "." <> format, else: output

    try do
      case run(
             "campfire-vips",
             ["transform", Path.expand(input), Path.expand(destination)] ++ arguments
           ) do
        {:ok, _} -> if destination == output, do: :ok, else: File.rename(destination, output)
        error -> error
      end
    after
      if destination != output, do: File.rm(destination)
    end
  rescue
    _ -> {:error, :invalid_transformation}
  end

  defp argument(value) when is_list(value), do: Enum.map_join(value, " ", &argument/1)

  defp argument(value) when is_binary(value) or is_number(value) or is_boolean(value),
    do: to_string(value)

  def audio_metadata(path) do
    with {:ok, json} <-
           run("ffprobe", [
             "-print_format",
             "json",
             "-show_streams",
             "-show_format",
             "-v",
             "error",
             Path.expand(path)
           ]),
         {:ok, values} when is_list(values) <- Campfire.JSON.decode(json) do
      streams = List.keyfind(values, "streams", 0, {"streams", []}) |> elem(1)

      audio =
        Enum.find(streams, fn stream ->
          is_list(stream) and List.keyfind(stream, "codec_type", 0) == {"codec_type", "audio"}
        end)

      pairs = audio || []

      metadata =
        for key <- ~w(duration bit_rate sample_rate tags), {^key, value} <- pairs, into: %{} do
          {key,
           case key do
             "duration" -> number(value)
             key when key in ["bit_rate", "sample_rate"] -> String.to_integer(value)
             _ -> value
           end}
        end

      {:ok, metadata}
    end
  end

  def video_metadata(path) do
    with {:ok, json} <-
           run("ffprobe", [
             "-v",
             "error",
             "-show_streams",
             "-show_format",
             "-print_format",
             "json",
             Path.expand(path)
           ]),
         {:ok, data} <- Jason.decode(json) do
      streams = data["streams"] || []
      video = Enum.find(streams, &(&1["codec_type"] == "video"))
      audio = Enum.find(streams, &(&1["codec_type"] == "audio"))
      video = video || %{}

      matrix =
        Enum.find(video["side_data_list"] || [], &(&1["side_data_type"] == "Display Matrix")) ||
          %{}

      rotation = get_in(video, ["tags", "rotate"]) || matrix["rotation"]
      ratio = video["display_aspect_ratio"]
      ratio = if ratio, do: String.split(ratio, ":", parts: 2) |> Enum.map(&String.to_integer/1)
      ratio = if ratio && hd(ratio) != 0, do: ratio
      width = if video["width"], do: number(video["width"]) / 1
      height = if video["height"], do: number(video["height"]) / 1
      height = if ratio && width, do: width * List.last(ratio) / hd(ratio), else: height

      {width, height} =
        if rotation && abs(number(rotation)) in [90, 270],
          do: {height, width},
          else: {width, height}

      duration = video["duration"] || get_in(data, ["format", "duration"])

      metadata =
        %{
          "width" => width,
          "height" => height,
          "duration" => if(duration, do: number(duration)),
          "angle" => if(rotation, do: trunc(number(rotation))),
          "display_aspect_ratio" => ratio,
          "audio" => !!audio,
          "video" => map_size(video) > 0
        }
        |> Map.reject(fn {_key, value} -> is_nil(value) end)

      {:ok, metadata}
    end
  end

  def preview(input, output) do
    filter =
      "select=eq(n\\,0)+eq(key\\,1)+gt(scene\\,0.015),loop=loop=-1:size=2,trim=start_frame=1"

    case run("ffmpeg", [
           "-v",
           "error",
           "-y",
           "-i",
           Path.expand(input),
           "-vf",
           filter,
           "-frames:v",
           "1",
           "-f",
           "image2",
           Path.expand(output)
         ]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp number(value) when is_number(value), do: value

  defp number(value) do
    case Float.parse(value) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp run(command, arguments) do
    case System.find_executable(command) do
      nil ->
        {:error, {:missing_executable, command}}

      executable ->
        case System.cmd(executable, arguments, stderr_to_stdout: true) do
          {output, 0} -> {:ok, output}
          {output, status} -> {:error, {command, status, output}}
        end
    end
  end
end
