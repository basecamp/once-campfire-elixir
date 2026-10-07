defmodule Campfire.ResponseFormats do
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils
  @moduledoc "Pinned controller templates and explicit respond_to format boundaries."
  import Plug.Conn

  @external_resource "vectors/mime-types.json"
  @types Jason.decode!(File.read!(@external_resource))
  @mime @types["lookup"]
  @wildcards @types["wildcards"]

  def head_type(conn), do: @types["canonical"][List.first(requested(conn))] || "text/html"

  def requested(conn) do
    params =
      case conn.params do
        %Plug.Conn.Unfetched{} -> %{}
        params when is_map(params) -> params
        _ -> %{}
      end

    cond do
      params["format"] ->
        [params["format"]]

      Regex.match?(~r/\.(json|xml)\z/, conn.request_path) ->
        [List.last(String.split(conn.request_path, "."))]

      true ->
        accept = get_req_header(conn, "accept") |> Enum.join(",")
        xhr? = get_req_header(conn, "x-requested-with") == ["XMLHttpRequest"]

        if accept == "" || (!xhr? && Regex.match?(~r/,\s*\*\/\*|\*\/\*\s*,/, accept)) do
          [if(xhr?, do: "js", else: "html")]
        else
          formats =
            accept
            |> String.split(",")
            |> Enum.with_index()
            |> Enum.sort_by(fn {type, index} ->
              quality =
                case Regex.run(~r/;\s*q="?([0-9.]+)/, type) do
                  [_, value] ->
                    case Float.parse(value) do
                      {number, _} -> number
                      _ -> 0.0
                    end

                  _ ->
                    1.0
                end

              {-quality, index}
            end)
            |> Enum.flat_map(fn {type, _} ->
              type = String.split(type, ";") |> hd() |> String.trim()

              cond do
                type == "*/*" -> ["all"]
                type in ["text/*", "application/*"] -> @wildcards[String.split(type, "/") |> hd()]
                @mime[type] -> [@mime[type]]
                true -> []
              end
            end)
            |> Enum.uniq()

          if formats == [], do: ["html"], else: formats
        end
    end
  end

  def prepare(conn) do
    route = conn.assigns[:rails_route] || %{}
    controller = route["controller"]
    action = route["action"]
    formats = requested(conn)

    allowed =
      case controller do
        "messages/by_bots" when action in ["index", "update"] ->
          ["html", "json"]

        "autocompletable/users" ->
          ["html", "json"]

        "accounts/users" ->
          ["turbo_stream"]

        "rooms/refreshes" ->
          ["turbo_stream"]

        "messages" when action in ["create", "destroy"] ->
          ["turbo_stream"]

        "messages" ->
          ["html"]

        controller
        when controller in [
               "welcome",
               "users",
               "users/profiles",
               "users/sidebars",
               "users/push_subscriptions",
               "accounts",
               "accounts/bots",
               "accounts/custom_styles",
               "rooms",
               "rooms/opens",
               "rooms/closeds",
               "rooms/directs",
               "rooms/involvements",
               "searches",
               "messages/boosts",
               "sessions",
               "sessions/transfers",
               "first_runs"
             ] ->
          ["html"]

        _ ->
          formats
      end

    mutation_format_error =
      controller == "messages" && action == "update" &&
        conn.assigns[:message_updated] == true && "html" not in formats && "all" not in formats

    unsupported =
      conn.status == 200 && "all" not in formats && !Enum.any?(formats, &(&1 in allowed))

    if !conn.assigns[:rails_exception] && (unsupported || mutation_format_error) do
      status = if mutation_format_error && "json" in formats, do: 500, else: 406
      {body, type} = Campfire.HttpResponse.error_parts(conn, status)
      Campfire.HttpResponse.exception_response(conn, status, body, type)
    else
      conn
    end
  end
end
