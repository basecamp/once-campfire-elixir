defmodule Campfire.HttpCompression do
  @moduledoc "Rack-compatible gzip selection and response framing."
  import Plug.Conn

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
              conn.state == :set_file -> nil
              parts = conn.assigns[:page_parts] -> gzip_parts(parts)
              true -> gzip(IO.iodata_to_binary(body), conn.assigns[:gzip_chunks])
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

  @doc """
  Splits a rendered page at `marker`, the placeholder standing in for `fragments`,
  returning the response iodata and the parts used by `gzip_parts/1`.
  Returns `nil` when the marker is absent.
  """
  def splice(html, marker, fragments) do
    case :binary.split(html, marker) do
      [before, rest] ->
        parts = [{:raw, before} | fragments] ++ [{:raw, rest}]
        {Enum.map(parts, &part_data/1), parts}

      [_] ->
        nil
    end
  end

  defp part_data({:raw, data}), do: data
  defp part_data({:fragment, _, _, html}), do: html

  # A gzip member assembled from separately deflated pieces. Each piece is a raw
  # deflate stream ending in a sync flush, primed with the bytes that precede it
  # in the page as its preset dictionary, so pieces concatenate into one valid
  # stream with the redundancy between messages intact. Cached fragments keep
  # their piece for a given predecessor; only the per-request page text is
  # compressed here.
  @doc false
  def gzip_parts(parts) do
    {pieces, crc, size, _} =
      Enum.reduce(parts, {[], :erlang.crc32(<<>>), 0, {nil, ""}}, fn part,
                                                                     {pieces, crc, size, previous} ->
        {piece, part_crc, part_size} = packed(part, previous)

        {[pieces | piece], :erlang.crc32_combine(crc, part_crc, part_size), size + part_size,
         identity(part)}
      end)

    mtime = DateTime.to_unix(Campfire.Clock.now())

    [
      <<0x1F, 0x8B, 8, 0, mtime::little-unsigned-32, 0, 3>>,
      pieces,
      # An empty final fixed-Huffman block ends the stream.
      <<3, 0>>,
      <<crc::little-unsigned-32, rem(size, 4_294_967_296)::little-unsigned-32>>
    ]
  end

  defp identity({:raw, data}), do: {nil, data}
  defp identity({:fragment, key, version, html}), do: {{key, version}, html}

  defp packed({:raw, data}, {_, before}), do: pack(data, before)

  # A fragment's piece depends on the bytes primed as its dictionary, so it is
  # cached per predecessor: after another fragment (whose identity fixes those
  # bytes) it is primed with that fragment; after per-request text it is
  # compressed without a dictionary.
  defp packed({:fragment, key, version, html}, {nil, _}),
    do: Campfire.FragmentCache.derived(key, version, html, {:piece, :start}, &pack/1)

  defp packed({:fragment, key, version, html}, {previous, before}),
    do: Campfire.FragmentCache.derived(key, version, html, {:piece, previous}, &pack(&1, before))

  @window 32_768

  @doc false
  def pack(data, before \\ "") do
    z = :zlib.open()

    try do
      :ok = :zlib.deflateInit(z, :default, :deflated, -15, 8, :default)
      dictionary = IO.iodata_to_binary(before)
      size = byte_size(dictionary)

      if size > 0,
        do:
          :zlib.deflateSetDictionary(
            z,
            binary_part(dictionary, max(size - @window, 0), min(size, @window))
          )

      piece = IO.iodata_to_binary(:zlib.deflate(z, data, :sync))
      {piece, :erlang.crc32(data), IO.iodata_length(data)}
    after
      :zlib.close(z)
    end
  end

  defp gzip(body, chunks) do
    z = :zlib.open()

    try do
      :ok = :zlib.deflateInit(z, :default, :deflated, 31, 8, :default)
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
