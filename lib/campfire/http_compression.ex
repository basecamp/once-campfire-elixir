defmodule Campfire.HttpCompression do
  @moduledoc "Rack-compatible gzip selection and response framing."
  import Plug.Conn
  # Rack::Deflater uses zlib's default level 6. Level 1 deflates a 450 KB room page about three
  # times faster; the decoded body is unchanged, the gzip bytes are not (a known difference).
  @level 1

  def level, do: @level

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
              compressed = conn.assigns[:precompressed] -> compressed
              parts = conn.assigns[:page_parts] -> gzip_parts(parts)
              chunks = conn.assigns[:gzip_chunks] -> gzip(IO.iodata_to_binary(body), chunks)
              true -> gzip_body(IO.iodata_to_binary(body), conn.assigns[:body_digest])
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

  # Accept-Encoding values repeat across requests; a (bounded) header's choice is kept.
  def encoding(raw) when byte_size(raw) <= 256,
    do:
      Campfire.FragmentCache.memo({:accept_encoding, raw}, 64 + byte_size(raw), fn ->
        negotiate(raw)
      end)

  def encoding(raw), do: negotiate(raw)

  defp negotiate(raw) do
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

  @doc "The response body of page parts built without a marker."
  def body(parts), do: Enum.map(parts, &part_data/1)

  @doc """
  A splice marker chosen once per boot, so a page shell rendered around it can be kept. It is
  random because some page text (an admin's custom styles) is not escaped.
  """
  def marker do
    case :persistent_term.get({__MODULE__, :marker}, nil) do
      nil ->
        marker = "<!--campfire-messages-" <> Base.encode16(:crypto.strong_rand_bytes(16)) <> "-->"
        :persistent_term.put({__MODULE__, :marker}, marker)
        marker

      marker ->
        marker
    end
  end

  defp part_data({:raw, data}), do: data
  defp part_data({:raw, data, _}), do: data
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

  @doc """
  The SHA-256 of a page part: computed for per-request text, and computed once and kept with
  the fragment for a cached fragment.
  """
  def digest({:raw, data}), do: :crypto.hash(:sha256, data)
  def digest({:raw, _, digest}), do: digest

  def digest({:fragment, key, version, html}),
    do: Campfire.FragmentCache.derived(key, version, html, :digest, &:crypto.hash(:sha256, &1))

  @doc "Page parts with each per-request text's digest attached, for `digest/1` and gzip reuse."
  def with_digests(parts),
    do:
      Enum.map(parts, fn
        {:raw, data} = part -> {:raw, data, digest(part)}
        part -> part
      end)

  defp identity({:raw, data}), do: {nil, data}
  defp identity({:raw, data, _}), do: {nil, data}
  defp identity({:fragment, key, version, html}), do: {{key, version}, html}

  defp packed({:raw, data}, {_, before}), do: pack(data, before)

  # Per-request text is the same on every visit to a page now that pages carry no token (a
  # room page's layout is about 45 KB). Its piece is kept by the text's digest and the digest
  # of the fragment primed as its dictionary, which together fix the bytes the piece encodes.
  defp packed({:raw, data, digest}, {previous, before}) when byte_size(data) >= 1024 do
    primed =
      case previous do
        nil -> nil
        {key, version} -> digest({:fragment, key, version, before})
      end

    Campfire.FragmentCache.memo({:raw_piece, digest, primed}, fn -> pack(data, before) end)
  end

  defp packed({:raw, data, _}, {_, before}), do: pack(data, before)

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
      :ok = :zlib.deflateInit(z, @level, :deflated, -15, 8, :default)
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

  # A whole body's deflate output is kept by the body's digest (shared with its ETag when one
  # was computed); only the gzip header's mtime is stamped per response.
  defp gzip_body(body, digest) do
    digest = digest || :crypto.hash(:sha256, body)

    {:gzip_body, digest}
    |> Campfire.FragmentCache.memo(fn -> gzip(body, nil) end)
    |> timestamp_header()
  end

  defp gzip(body, chunks) do
    z = :zlib.open()

    try do
      :ok = :zlib.deflateInit(z, @level, :deflated, 31, 8, :default)
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
