defmodule Campfire.HttpCompression do
  @moduledoc "Rack-compatible gzip selection and response framing."
  import Plug.Conn
  # Rack::Deflater uses zlib's default level (6). Level 1 compresses this app's
  # HTML about 2.5x faster for roughly 1.5x the wire bytes; CAMPFIRE_GZIP_LEVEL
  # selects another level (1-9) at startup.
  def level, do: :persistent_term.get({__MODULE__, :level}, 1)

  def configure_level do
    level =
      case Integer.parse(System.get_env("CAMPFIRE_GZIP_LEVEL", "1")) do
        {n, ""} when n in 1..9 -> n
        _ -> 1
      end

    :persistent_term.put({__MODULE__, :level}, level)
  end

  def apply(conn) do
    body = conn.resp_body
    cache = Enum.join(get_resp_header(conn, "cache-control"))

    if conn.status in [204, 304] || conn.status in 100..199 ||
         String.contains?(cache, "no-transform") ||
         get_resp_header(conn, "content-encoding") != [] ||
         !(is_binary(body) || is_list(body) || conn.state == :set_file) do
      conn
    else
      raw = List.first(get_req_header(conn, "accept-encoding")) || ""

      case encoding(raw) do
        "identity" ->
          conn

        "gzip" ->
          compressed =
            cond do
              conn.state == :set_file ->
                nil

              is_binary(conn.assigns[:precompressed_gzip]) ->
                timestamp_header(conn.assigns[:precompressed_gzip])

              match?(%{gzip: g} when is_binary(g), conn.assigns[:response_cache_hit]) ->
                timestamp_header(conn.assigns[:response_cache_hit].gzip)

              true ->
                compressed = gzip(IO.iodata_to_binary(body), conn.assigns[:gzip_chunks])

                if hit = conn.assigns[:response_cache_hit],
                  do: Campfire.ResponseCache.put_gzip(hit, compressed)

                compressed
            end

          %{conn | resp_body: compressed}
          |> put_resp_header("content-encoding", "gzip")
          |> delete_resp_header("content-length")

        nil ->
          path =
            conn.request_path <>
              if(conn.query_string == "", do: "", else: "?" <> conn.query_string)

          body = "An acceptable encoding for the requested resource #{path} could not be found."

          conn =
            if conn.state == :set_file do
              Process.put(:campfire_encoding_error, body)
              conn
            else
              conn
            end

          %{
            conn
            | status: 406,
              resp_body: body,
              resp_cookies: %{},
              resp_headers: [
                {"content-type", "text/plain"},
                {"content-length", to_string(byte_size(body))}
              ]
          }
      end
    end
  end

  # Exact matches for the headers browsers and proxies send; the general
  # negotiation below gives the same answers for them.
  def encoding(""), do: "identity"
  def encoding("gzip"), do: "gzip"
  def encoding("gzip, deflate"), do: "gzip"
  def encoding("gzip, deflate, br"), do: "gzip"
  def encoding("gzip, deflate, br, zstd"), do: "gzip"

  def encoding(raw) do
    available = ["gzip", "identity"]

    parsed =
      raw
      |> String.split(",", trim: true)
      |> Enum.take(16)
      |> Enum.map(fn part ->
        [value | params] = String.split(part, ";", parts: 2)

        quality =
          case params do
            [p] ->
              case Regex.run(~r/\Aq=([0-9.]+)/, String.trim(p)) do
                [_, q] ->
                  case Float.parse(if(String.starts_with?(q, "."), do: "0" <> q, else: q)) do
                    {v, _} -> v
                    _ -> 0.0
                  end

                _ ->
                  1.0
              end

            _ ->
              1.0
          end

        {String.trim(value), quality}
      end)

    {expanded, _} =
      Enum.reduce(parsed, {[], false}, fn {name, q}, {acc, seen} ->
        pref = Enum.find_index(available, &(&1 == name)) || length(available)

        if name == "*" do
          if seen,
            do: {acc, seen},
            else:
              {acc ++ Enum.map(available -- Enum.map(parsed, &elem(&1, 0)), &{&1, q, pref}), true}
        else
          {acc ++ [{name, q, pref}], seen}
        end
      end)

    candidates = expanded |> Enum.sort_by(fn {_, q, p} -> {-q, p} end) |> Enum.map(&elem(&1, 0))
    candidates = if "identity" in candidates, do: candidates, else: candidates ++ ["identity"]
    excluded = for {name, q, _} <- expanded, q == 0.0, do: name
    Enum.find(candidates, &(&1 in available && &1 not in excluded))
  end

  def timestamp_header(<<prefix::binary-size(4), _mtime::binary-size(4), rest::binary>>),
    do:
      <<prefix::binary, DateTime.to_unix(Campfire.Clock.now())::little-unsigned-size(32),
        rest::binary>>

  @doc "Rack::Deflater's chunked gzip framing of `body` (or of the given chunks)."
  def compress(body, chunks \\ nil), do: gzip(body, chunks)

  defp gzip(body, chunks) do
    z = :zlib.open()

    try do
      :ok = :zlib.deflateInit(z, level(), :deflated, 31, 8, :default)
      chunks = chunks || if(body == "", do: [], else: [body])
      parts = Enum.map(chunks, &:zlib.deflate(z, &1, :sync))
      bytes = IO.iodata_to_binary([parts, :zlib.deflate(z, "", :finish)])
      :ok = :zlib.deflateEnd(z)
      timestamp_header(bytes)
    after
      :zlib.close(z)
    end
  end
end
