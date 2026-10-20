defmodule Campfire.Media do
  @moduledoc "Image processing through libvips (Vix) and audio/video through FFprobe and FFmpeg."

  def image_metadata(path), do: Campfire.Media.Vips.image_metadata(path)

  def resize(input, output, width, height)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    Campfire.Media.Vips.resize(input, output, width, height)
  end

  def convert(input, output), do: Campfire.Media.Vips.convert(input, output)

  def transform(input, output, entries), do: Campfire.Media.Vips.transform(input, output, entries)

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
         {:ok, %Jason.OrderedObject{values: values}} <-
           Campfire.JSON.decode_ordered(json) do
      streams = List.keyfind(values, "streams", 0, {"streams", []}) |> elem(1)

      audio =
        Enum.find(streams, fn %Jason.OrderedObject{values: pairs} ->
          List.keyfind(pairs, "codec_type", 0) == {"codec_type", "audio"}
        end)

      pairs = if audio, do: audio.values, else: []

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
         {:ok, data} <- Campfire.JSON.decode(json) do
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
