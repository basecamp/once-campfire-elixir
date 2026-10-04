defmodule Campfire.PublicFiles do
  @moduledoc "The pinned public documents served before controller recognition."
  import Plug.Conn
  @external_resource "priv/compat/rack-mime.json"
  @mime Jason.decode!(File.read!(@external_resource))
  @files ~w(robots.txt 404.html 422.html 500.html 502.html)
  def init(opts), do: opts

  def call(%{method: method} = conn, _) when method in ["GET", "HEAD"] do
    decoded = URI.decode(conn.request_path)

    parts =
      decoded
      |> String.split("/", trim: true)
      |> Enum.reduce([], fn
        ".", acc -> acc
        "..", [_ | rest] -> rest
        "..", [] -> []
        part, acc -> [part | acc]
      end)
      |> Enum.reverse()

    if String.contains?(decoded, <<0>>) do
      conn
    else
      case parts do
        [name] when name in @files ->
          path = Path.join([:code.priv_dir(:campfire), "public", name])
          serve(conn, path, Map.fetch!(@mime, Path.extname(path)))

        ["assets" | [_ | _] = rest] ->
          path = Path.join([:code.priv_dir(:campfire), "static/assets" | rest])

          if File.regular?(path),
            do: serve(conn, path, Map.get(@mime, Path.extname(path), "text/plain")),
            else: conn

        _ ->
          conn
      end
    end
  end

  def call(conn, _), do: conn

  defp serve(conn, path, type) do
    method = conn.method

    {data, modified} =
      Campfire.ResponseCache.static({:file, path}, fn ->
        {File.read!(path),
         DateTime.from_unix!(File.stat!(path, time: :posix).mtime)
         |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")}
      end)

    modified =
      if System.get_env("CAMPFIRE_CLOCK"),
        do: Calendar.strftime(Campfire.Clock.now(), "%a, %d %b %Y %H:%M:%S GMT"),
        else: modified

    if List.first(get_req_header(conn, "if-modified-since")) == modified do
      conn
      |> delete_resp_header("cache-control")
      |> put_resp_header("content-length", "0")
      |> send_resp(304, "")
      |> halt()
    else
      conn =
        conn
        |> put_resp_header("content-type", type)
        |> put_resp_header("last-modified", modified)
        |> put_resp_header("cache-control", "public, max-age=2592000")

      size = byte_size(data)

      {conn, status, body} =
        case Campfire.Rack.ranges(List.first(get_req_header(conn, "range")), size) do
          nil ->
            gzip =
              Campfire.ResponseCache.static({:gzip, path}, fn ->
                Campfire.HttpCompression.compress(data, chunks(data))
              end)

            {assign(conn, :precompressed_gzip, gzip), 200, data}

          [] ->
            {conn
             |> delete_resp_header("cache-control")
             |> delete_resp_header("last-modified")
             |> put_resp_header("content-range", "bytes */#{size}"), 416,
             "Byte range unsatisfiable\n"}

          [[first, last]] ->
            {conn
             |> assign(:gzip_chunks, chunks(binary_part(data, first, last - first + 1)))
             |> put_resp_header("content-range", "bytes #{first}-#{last}/#{size}"), 206,
             binary_part(data, first, last - first + 1)}

          ranges ->
            parts =
              Enum.flat_map(ranges, fn [first, last] ->
                [
                  "\r\n--AaB03x\r\ncontent-type: #{type}\r\ncontent-range: bytes #{first}-#{last}/#{size}\r\n\r\n"
                  | chunks(binary_part(data, first, last - first + 1))
                ]
              end) ++ ["\r\n--AaB03x--\r\n"]

            {assign(conn, :gzip_chunks, parts), 206, IO.iodata_to_binary(parts)}
        end

      conn =
        conn
        |> put_resp_header("vary", "Accept-Encoding")
        |> put_resp_header("content-length", to_string(byte_size(body)))

      conn = Campfire.HttpCompression.apply(%{conn | status: status, resp_body: body})

      conn =
        case conn.adapter do
          {Bandit.Adapter, adapter} -> %{conn | adapter: {Campfire.HttpAdapter, adapter}}
          _ -> conn
        end

      conn |> send_resp(conn.status, if(method == "HEAD", do: "", else: conn.resp_body)) |> halt()
    end
  end

  defp chunks(""), do: []

  defp chunks(body) do
    size = min(byte_size(body), 8192)
    <<chunk::binary-size(size), rest::binary>> = body
    [chunk | chunks(rest)]
  end
end
