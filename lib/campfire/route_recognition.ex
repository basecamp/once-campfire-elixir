defmodule Campfire.RouteRecognition do
  @moduledoc "Pinned Rails route order, verbs and optional format recognition."
  import Plug.Conn
  @external_resource "vectors/route-actions.json"
  @routes (for route <- Jason.decode!(File.read!(@external_resource)) do
             path = route["path"]
             format? = String.ends_with?(path, "(.:format)")
             base = String.replace_suffix(path, "(.:format)", "")

             pattern =
               Regex.escape(base)
               |> then(&Regex.replace(~r/:([a-z_]+)/, &1, fn _, key -> "(?<#{key}>[^/.]+)" end))
               |> then(&Regex.replace(~r/\\\*([a-z_]+)/, &1, fn _, key -> "(?<#{key}>.+)" end))

             regex =
               Regex.compile!(
                 "\\A" <>
                   pattern <> if(format?, do: "(?:\\.(?<format>[^/]+))?", else: "") <> "/?\\z"
               )

             {route, regex, String.split(route["verb"], "|")}
           end)

  @buckets Enum.group_by(@routes, fn {route, _, _} ->
             route["path"]
             |> String.split("/", trim: true)
             |> List.first()
             |> then(fn
               nil -> ""
               segment -> String.split(segment, [".", "("], parts: 2) |> hd()
             end)
           end)

  def init(options), do: options
  def call(%{request_path: "/cable"} = conn, _), do: conn

  def call(conn, _) do
    method = if conn.method == "HEAD", do: "GET", else: conn.method

    match =
      Enum.find_value(
        Map.get(
          @buckets,
          conn.request_path
          |> String.split("/", trim: true)
          |> List.first()
          |> then(&String.split(&1 || "", ".", parts: 2))
          |> hd(),
          []
        ),
        fn {route, regex, verbs} ->
          if method in verbs do
            if params = Regex.named_captures(regex, conn.request_path), do: {route, params}
          end
        end
      )

    case match do
      {%{"status" => "implemented"} = route, params} ->
        params =
          params
          |> Enum.reject(fn {_, value} -> value == "" end)
          |> Map.new(fn {key, value} -> {key, URI.decode(value)} end)

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
end
