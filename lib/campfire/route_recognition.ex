defmodule Campfire.RouteRecognition do
  @moduledoc "Pinned Rails route order, verbs and optional format recognition."
  import Plug.Conn
  @external_resource "vectors/route-actions.json"
  @routes Jason.decode!(File.read!(@external_resource))

  def init(options), do: options
  def call(%{request_path: "/cable"} = conn, _), do: conn

  def call(conn, _) do
    method = if conn.method == "HEAD", do: "GET", else: conn.method
    raw = segments(conn.request_path)
    tokens = raw |> drop_trailing_slash() |> Enum.map(&token/1)

    match =
      case recognize(method, tokens, raw) do
        {index, params} -> {elem(routes(), index), params}
        nil -> nil
      end

    case match do
      {%{"status" => "implemented"} = route, params} ->
        params =
          for {key, value} <- params,
              value not in [nil, ""],
              into: %{},
              do: {key, URI.decode(value)}

        params =
          if route["controller"] in ["messages/by_bots", "messages/boosts/by_bots"],
            do: Map.put_new(params, "format", "json"),
            else: params

        path_info =
          case params["format"] do
            nil ->
              conn.path_info

            format ->
              List.update_at(conn.path_info, -1, &String.replace_suffix(&1, "." <> format, ""))
          end

        %{conn | path_info: path_info, params: Map.merge(conn.params, params)}
        |> assign(:rails_route, route)

      {%{"status" => "missing_controller"}, _} ->
        Campfire.HttpResponse.error(conn, 500) |> halt()

      _ ->
        Campfire.HttpResponse.error(conn, 404) |> halt()
    end
  end

  # Rails route recognition compiled into ordered function clauses over path
  # segments. Each segment is tokenized as {before_first_dot, extension}, which
  # expresses Journey's `[^/.]+` dynamic segments and optional `(.:format)`
  # suffix as patterns; `*glob` takes the remaining raw segments. Clause order
  # is route table order, so the first matching route wins as in Rails.
  defp segments(path) do
    case :binary.split(path, "/", [:global]) do
      ["" | rest] -> rest
      other -> other
    end
  end

  # Journey patterns accept one optional trailing slash.
  defp drop_trailing_slash(segments) do
    case Enum.split(segments, -1) do
      {rest, [""]} -> rest
      _ -> segments
    end
  end

  defp token(segment) do
    case :binary.split(segment, ".") do
      [name, extension] -> {name, extension}
      [name] -> {name, nil}
    end
  end

  defp routes, do: unquote(Macro.escape(List.to_tuple(@routes)))

  for {route, index} <- Enum.with_index(@routes), verb <- String.split(route["verb"], "|") do
    path = route["path"]
    format? = String.ends_with?(path, "(.:format)")
    parts = path |> String.replace_suffix("(.:format)", "") |> String.split("/", trim: true)
    {fixed, glob} = Enum.split_while(parts, &(not String.starts_with?(&1, "*")))
    count = length(fixed)
    format = Macro.var(:format, __MODULE__)

    {patterns, guards, params} =
      fixed
      |> Enum.with_index(1)
      |> Enum.reduce({[], [], []}, fn {part, position}, {patterns, guards, params} ->
        # Only the last segment of a non-glob route may carry the format suffix.
        extension = if format? and glob == [] and position == count, do: format, else: nil

        case :binary.split(part, ":") do
          [prefix, name] ->
            # A dynamic segment, optionally after a literal prefix such as `@:message_id`.
            var = Macro.var(String.to_atom("segment_#{position}"), __MODULE__)
            segment = if prefix == "", do: var, else: quote(do: unquote(prefix) <> unquote(var))

            {[quote(do: {unquote(segment), unquote(extension)}) | patterns],
             [quote(do: unquote(var) != "") | guards], [{name, var} | params]}

          [literal] ->
            {[quote(do: {unquote(literal), unquote(extension)}) | patterns], guards, params}
        end
      end)

    patterns = Enum.reverse(patterns)
    params = Enum.reverse(params)

    guards =
      if format? and glob == [] and count > 0,
        do: [quote(do: is_nil(unquote(format)) or unquote(format) != "") | guards],
        else: guards

    {tokens, raw, guards, params} =
      case glob do
        [] ->
          {patterns, Macro.var(:_raw, __MODULE__), guards, params}

        ["*" <> name] ->
          rest = Macro.var(:rest, __MODULE__)
          skipped = List.duplicate(Macro.var(:_, __MODULE__), count)

          {quote(do: [unquote_splicing(patterns) | _]),
           quote(do: [unquote_splicing(skipped) | unquote(rest)]),
           [quote(do: unquote(rest) not in [[], [""]]) | guards],
           params ++ [{name, quote(do: Enum.join(unquote(rest), "/"))}]}
      end

    # The root route `/` also accepts its optional trailing slash: `//`.
    {tokens, raw, guards} =
      if parts == [],
        do:
          {Macro.var(:_tokens, __MODULE__), quote(do: raw), [quote(do: raw in [[""], ["", ""]])]},
        else: {tokens, raw, guards}

    guard = Enum.reduce(guards, true, &quote(do: unquote(&1) and unquote(&2)))

    params =
      if format? and glob == [] and count > 0, do: params ++ [{"format", format}], else: params

    defp recognize(unquote(verb), unquote(tokens), unquote(raw)) when unquote(guard),
      do: {unquote(index), unquote(params)}
  end

  defp recognize(_, _, _), do: nil
end
