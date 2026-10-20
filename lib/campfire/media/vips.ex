defmodule Campfire.Media.Vips do
  @moduledoc """
  Active Storage's ruby-vips/ImageProcessing pipeline through Vix.

  The operation sequence, option names and ordering mirror `image_processing` 1.14.0's vips
  processor: resize on load, `thumbnail_image` plus the fixed 3x3 sharpen mask, `rot` for exact
  quarter turns and `similarity` otherwise, `gravity` padding, and the loader/saver option
  filtering the reference performs by introspecting the format operation.
  """

  alias Vix.Vips.{Image, Operation}

  @sharpen_mask [[-1, -1, -1], [-1, 32, -1], [-1, -1, -1]]
  @max_coord 10_000_000

  @directions %{
    "horizontal" => :VIPS_DIRECTION_HORIZONTAL,
    "vertical" => :VIPS_DIRECTION_VERTICAL
  }
  @gravity %{
    "north" => :VIPS_COMPASS_DIRECTION_NORTH,
    "north-east" => :VIPS_COMPASS_DIRECTION_NORTH_EAST,
    "east" => :VIPS_COMPASS_DIRECTION_EAST,
    "south-east" => :VIPS_COMPASS_DIRECTION_SOUTH_EAST,
    "south" => :VIPS_COMPASS_DIRECTION_SOUTH,
    "south-west" => :VIPS_COMPASS_DIRECTION_SOUTH_WEST,
    "west" => :VIPS_COMPASS_DIRECTION_WEST,
    "north-west" => :VIPS_COMPASS_DIRECTION_NORTH_WEST,
    "centre" => :VIPS_COMPASS_DIRECTION_CENTRE
  }
  @extend %{
    "background" => :VIPS_EXTEND_BACKGROUND,
    "copy" => :VIPS_EXTEND_COPY,
    "repeat" => :VIPS_EXTEND_REPEAT,
    "mirror" => :VIPS_EXTEND_MIRROR,
    "white" => :VIPS_EXTEND_WHITE,
    "black" => :VIPS_EXTEND_BLACK
  }
  @angles %{90 => :VIPS_ANGLE_D90, 180 => :VIPS_ANGLE_D180, 270 => :VIPS_ANGLE_D270}

  # Vix exposes no `crop` or `hasalpha`; `crop` is libvips' extract_area alias.
  @operations %{
    "crop" => :extract_area,
    "flip" => :flip,
    "resize" => :resize,
    "sharpen" => :sharpen,
    "gamma" => :gamma,
    "flatten" => :flatten,
    "smartcrop" => :smartcrop,
    "gaussblur" => :gaussblur
  }

  def image_metadata(path) do
    case load(path, access: :VIPS_ACCESS_SEQUENTIAL) do
      {:ok, image} ->
        with {:ok, width} <- Image.header_value(image, "width"),
             {:ok, height} <- Image.header_value(image, "height") do
          {:ok, %{"width" => width, "height" => height} |> swap_for_orientation(image)}
        end

      {:error, _reason} ->
        {:ok, %{}}
    end
  end

  def resize(input, output, width, height) do
    with {:ok, image} <- load(input),
         {:ok, rotated} <- autorot(image),
         {:ok, thumbnail} <-
           Operation.thumbnail_image(rotated, width,
             height: height,
             size: :VIPS_SIZE_DOWN,
             no_rotate: true
           ),
         {:ok, sharpened} <- sharpen(thumbnail) do
      Image.write_to_file(sharpened, output)
    end
  end

  def convert(input, output) do
    with {:ok, image} <- load(input),
         {:ok, rotated} <- autorot(image) do
      Image.write_to_file(rotated, output)
    end
  end

  def transform(input, output, entries) do
    {loader_options, saver_options, autorot?, operations, format} = normalize(entries)
    destination = if format, do: output <> "." <> format, else: output

    try do
      with {:ok, image} <- load(input, filtered(input, loader_options, :load)),
           {:ok, rotated} <- maybe_autorot(image, autorot?),
           {:ok, transformed} <- apply_all(rotated, operations),
           :ok <-
             write(transformed, destination, filtered(destination, saver_options, :save)) do
        if destination == output, do: :ok, else: File.rename(destination, output)
      end
    rescue
      _error -> {:error, :invalid_transformation}
    catch
      :exit, _reason -> {:error, :invalid_transformation}
    after
      if destination != output, do: File.rm(destination)
    end
  end

  defp normalize(entries) do
    {loader, saver, autorot?, operations, format} =
      Enum.reduce(entries, {[], [], true, [], nil}, fn {name, value},
                                                       {loader, saver, autorot, operations,
                                                        format} ->
        cond do
          name == "convert" ->
            {loader, saver, autorot, operations,
             if(value in [nil, false, "", []], do: format, else: value)}

          name in ["format"] or value in [nil, false, "", [], %{}] ->
            {loader, saver, autorot, operations, format}

          name == "loader" ->
            keywords = keywords(value)
            {loader ++ keywords, saver, autorot?(keywords, autorot), operations, format}

          name == "saver" ->
            {loader, saver ++ keywords(value), autorot, operations, format}

          true ->
            {positional, keywords} = positional(value)

            positional =
              if name in ["resize_to_limit", "resize_to_fit"],
                do: default_dimensions(positional),
                else: positional

            {loader, saver, autorot, operations ++ [{name, positional, keywords}], format}
        end
      end)

    {loader, saver, autorot?, operations, format}
  end

  defp autorot?(keywords, autorot) do
    case List.keyfind(keywords, "autorot", 0) do
      nil -> autorot
      {_key, value} -> value not in [false, "false"]
    end
  end

  defp keywords(value) when is_map(value),
    do: Enum.map(value, fn {key, value} -> {to_string(key), value} end)

  defp keywords(value) when is_list(value), do: keywords(List.last(value))
  defp keywords(_value), do: []

  defp positional(values) when is_list(values) do
    case List.last(values) do
      map when is_map(map) -> {Enum.drop(values, -1), keywords(map)}
      _ -> {values, []}
    end
  end

  defp positional(value) when is_map(value), do: {[], keywords(value)}
  defp positional(value), do: {[value], []}

  defp default_dimensions(values), do: Enum.map(values, &(&1 || @max_coord))

  defp filtered(path, options, direction) do
    case optional_inputs(path, direction) do
      {:ok, names} ->
        allowed = Map.new(names, &{&1, String.to_atom(&1)})

        options
        |> Enum.flat_map(&translate_option/1)
        |> Enum.flat_map(fn {key, value} ->
          case Map.fetch(allowed, key) do
            {:ok, param} -> [{param, value}]
            :error -> []
          end
        end)

      :error ->
        []
    end
  end

  # `ImageProcessing::Vips::Utils.select_valid_options/2`: keep only options the loader or saver
  # declares. Vix's operation spec is the same introspection libvips exposes.
  defp optional_inputs(path, direction) do
    case foreign_name(path, direction) do
      {:ok, name} -> optional_inputs(name)
      :error -> :error
    end
  end

  defp optional_inputs(name) do
    {:ok, Enum.map(operation_spec(name).in_opt_spec, & &1.param_name)}
  rescue
    _error -> :error
  end

  defp operation_spec(name), do: Vix.Vips.Operation.Helper.operation_args_spec(name)

  defp foreign_name(path, :load) do
    case Vix.Vips.Foreign.find_load(Path.expand(path)) do
      {:ok, name} -> {:ok, name}
      {:error, _reason} -> :error
    end
  end

  defp foreign_name(path, :save) do
    case Vix.Vips.Foreign.find_save(Path.expand(path)) do
      {:ok, name} -> {:ok, name}
      {:error, _reason} -> :error
    end
  end

  # The reference maps `quality` to `Q` itself and libvips deprecated `strip` into `keep: NONE`.
  defp translate_option({"strip", value}) when value in [true, "true"] do
    [{"keep", [:VIPS_FOREIGN_KEEP_NONE]}]
  end

  defp translate_option({"strip", _value}), do: []
  defp translate_option({"quality", value}), do: [{"Q", value}]
  defp translate_option({"autorot", _value}), do: []
  defp translate_option({key, value}) when is_atom(key), do: [{Atom.to_string(key), value}]
  defp translate_option({key, value}), do: [{key, value}]

  defp load(path, options \\ []) do
    Image.new_from_file(Path.expand(path), page_options(path) ++ options)
  end

  defp page_options(path) do
    case optional_inputs(path, :load) do
      {:ok, names} -> if "page" in names, do: [page: 0], else: []
      :error -> []
    end
  end

  defp maybe_autorot(image, true), do: autorot(image)
  defp maybe_autorot(image, false), do: {:ok, image}

  defp autorot(image) do
    case Operation.autorot(image) do
      {:ok, {rotated, _transform}} -> {:ok, rotated}
      error -> error
    end
  end

  defp apply_all(image, operations) do
    Enum.reduce_while(operations, {:ok, image}, fn operation, {:ok, current} ->
      case apply_one(current, operation) do
        {:ok, next} -> {:cont, {:ok, next}}
        error -> {:halt, error}
      end
    end)
  end

  defp apply_one(image, {"resize_to_limit", [width, height], keywords}) do
    thumbnail(image, width, height, [{:size, :VIPS_SIZE_DOWN} | keywords])
  end

  defp apply_one(image, {"resize_to_fit", [width, height], keywords}) do
    thumbnail(image, width, height, keywords)
  end

  defp apply_one(image, {"resize_to_fill", [width, height], keywords}) do
    thumbnail(image, width, height, [{:crop, :VIPS_INTERESTING_CENTRE} | keywords])
  end

  defp apply_one(image, {"resize_to_cover", [width, height], keywords}) do
    case {ratio(image), width / height} do
      {ratio, target} when ratio > target ->
        thumbnail(image, @max_coord, height, [{:crop, :VIPS_INTERESTING_NONE} | keywords])

      _ ->
        thumbnail(image, width, @max_coord, [{:crop, :VIPS_INTERESTING_NONE} | keywords])
    end
  end

  defp apply_one(image, {"resize_and_pad", [width, height], keywords}) do
    {gravity, keywords} = pop(keywords, "gravity", "centre")
    {alpha, keywords} = pop(keywords, "alpha", false)
    {padding, keywords} = split(keywords, ["background", "extend"])

    with {:ok, thumbnail} <- thumbnail(image, width, height, keywords),
         {:ok, with_alpha} <- ensure_alpha(thumbnail, alpha),
         {:ok, direction} <- gravity_direction(gravity),
         {:ok, padded} <-
           Operation.gravity(
             with_alpha,
             direction,
             trunc(width),
             trunc(height),
             gravity_options(padding)
           ) do
      {:ok, padded}
    end
  end

  defp apply_one(image, {"rotate", [degrees], []}) when is_map_key(@angles, degrees) do
    Operation.rot(image, Map.fetch!(@angles, degrees))
  end

  defp apply_one(image, {"rotate", [degrees], keywords}) do
    Operation.similarity(
      image,
      Keyword.merge([angle: degrees * 1.0], resolve("similarity", keywords))
    )
  end

  defp apply_one(image, {name, positional, keywords}) do
    case Map.fetch(@operations, name) do
      {:ok, function} ->
        args = [image | Enum.map(positional, &enum_value/1)]

        case resolve(Atom.to_string(function), keywords) do
          [] -> apply(Operation, function, args)
          options -> apply(Operation, function, args ++ [options])
        end

      :error ->
        {:error, :unsupported_operation}
    end
  end

  defp resolve(name, keywords) do
    case optional_inputs(name) do
      {:ok, names} ->
        allowed = Map.new(names, &{&1, String.to_atom(&1)})

        Enum.flat_map(keywords, fn {key, value} ->
          case Map.fetch(allowed, to_string(key)) do
            {:ok, param} -> [{param, value}]
            :error -> []
          end
        end)

      :error ->
        []
    end
  end

  defp pop(keywords, name, default) do
    case List.keyfind(keywords, name, 0) do
      nil -> {default, keywords}
      {_name, value} -> {value, List.keydelete(keywords, name, 0)}
    end
  end

  defp split(keywords, names) do
    Enum.split_with(keywords, fn {key, _value} -> to_string(key) in names end)
  end

  defp enum_value(value) when is_binary(value) do
    case Map.fetch(@directions, value) do
      {:ok, direction} -> direction
      :error -> value
    end
  end

  defp enum_value(value), do: value

  defp thumbnail(image, width, height, keywords) do
    {sharpen, keywords} = pop(keywords, "sharpen", true)

    options =
      Keyword.merge(
        [height: trunc(height), no_rotate: true],
        resolve("thumbnail_image", keywords)
      )

    with {:ok, thumbnail} <- Operation.thumbnail_image(image, trunc(width), options) do
      if sharpen, do: sharpen(thumbnail), else: {:ok, thumbnail}
    end
  end

  defp gravity_options(padding) do
    [
      background:
        option(padding, "background") && Enum.map(option(padding, "background"), &(&1 * 1.0)),
      extend: option(padding, "extend") && extend(option(padding, "extend"))
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp option(keywords, name) do
    case List.keyfind(keywords, name, 0) do
      nil -> nil
      {_name, value} -> value
    end
  end

  defp ensure_alpha(image, true) do
    if alpha?(image), do: {:ok, image}, else: Operation.bandjoin_const(image, [255.0])
  end

  defp ensure_alpha(image, false), do: {:ok, image}

  # `vips_image_hasalpha` is not exposed as an operation; this is its rule.
  defp alpha?(image) do
    with {:ok, bands} <- Image.header_value(image, "bands"),
         {:ok, interpretation} <- Image.header_value(image, "interpretation") do
      case interpretation
           |> to_string()
           |> String.downcase()
           |> String.replace_prefix("vips_interpretation_", "") do
        "b-w" ->
          bands > 1

        "grey16" ->
          bands > 1

        interpretation
        when interpretation in ~w(rgb cmc lch labs srgb yxy xyz lab rgb16 scrgb hsv) ->
          bands > 3

        "cmyk" ->
          bands > 4

        _ ->
          false
      end
    else
      _ -> false
    end
  end

  defp sharpen(image) do
    with {:ok, mask} <- Image.new_matrix_from_array(3, 3, @sharpen_mask, scale: 24.0, offset: 0.0) do
      Operation.conv(image, mask, precision: :VIPS_PRECISION_INTEGER)
    end
  end

  defp write(image, path, options), do: Image.write_to_file(image, Path.expand(path), options)

  defp ratio(image) do
    with {:ok, width} <- Image.header_value(image, "width"),
         {:ok, height} <- Image.header_value(image, "height") do
      width / height
    else
      _ -> 1
    end
  end

  defp gravity_direction(name) do
    case Map.fetch(@gravity, to_string(name)) do
      {:ok, direction} -> {:ok, direction}
      :error -> {:error, :invalid_gravity}
    end
  end

  defp extend(name) do
    case Map.fetch(@extend, to_string(name)) do
      {:ok, extend} -> extend
      :error -> :VIPS_EXTEND_BACKGROUND
    end
  end

  defp swap_for_orientation(%{} = metadata, image) do
    case Image.header_value(image, "exif-ifd0-Orientation") do
      {:ok, orientation} when is_binary(orientation) ->
        if orientation =~ ~r/Right-top|Left-bottom|Top-right|Bottom-left/,
          do: %{metadata | "width" => metadata["height"], "height" => metadata["width"]},
          else: metadata

      _ ->
        metadata
    end
  end
end
