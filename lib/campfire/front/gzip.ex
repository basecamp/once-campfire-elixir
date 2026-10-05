defmodule Campfire.Front.Gzip do
  @moduledoc """
  Thruster's response compression (`gzhttp`), for responses the app did not encode.

  Bodies of at least 1 KiB with a compressible type are gzipped when the client accepts it.
  With `GZIP_COMPRESSION_JITTER`, the gzip header carries a comment whose length depends on
  the content, so equal bodies compress identically and sizes don't leak a secret (BREACH).
  Thruster also offers zstd; only gzip is implemented.
  """
  @min_size 1024
  @jitter_sample 64 * 1024

  @exclude_contains ~w(compress zip snappy lzma xz zstd brotli stuffit)
  @exclude_prefix ~w(video/ audio/ image/jp image/jpeg image/jpg image/png image/apng image/webp image/gif image/avif image/heic image/heif image/jxl)

  @doc "Whether the request accepts gzip (`parseEncodingQValue` for gzip, ignoring zstd)."
  def accepts?("HEAD", _), do: false
  def accepts?(_, nil), do: false

  def accepts?(_, accept_encoding) do
    accept_encoding
    |> String.split(",")
    |> Enum.find_value(0.0, fn part ->
      [coding | params] = String.split(part, ";")

      if coding |> String.trim() |> String.downcase() == "gzip" do
        Enum.reduce(params, 1.0, fn param, q ->
          case String.trim(param) do
            "q=" <> value ->
              case Float.parse(value) do
                {value, _} -> value |> max(0.0) |> min(1.0)
                :error -> 0.0
              end

            _ ->
              q
          end
        end)
      end
    end) > 0.0
  end

  @doc "The request headers that make a response user-specific (`DisableOnAuth`)."
  def user_specific_request?(headers),
    do:
      Enum.any?(headers, fn {name, value} ->
        name in ["cookie", "authorization", "x-csrf-token"] and value != ""
      end)

  def user_specific_response?(headers) do
    cache_control =
      for directive <-
            headers |> header("cache-control") |> String.downcase() |> String.split(","),
          do: directive |> String.trim() |> String.split("=") |> hd()

    vary =
      for token <- headers |> header("vary") |> String.split(","),
          do: token |> String.trim() |> String.downcase()

    header(headers, "set-cookie") != "" or "private" in cache_control or
      "no-store" in cache_control or "cookie" in vary
  end

  @doc "`Vary: Accept-Encoding` on every response (`:replace` keeps an existing Vary)."
  def add_vary(headers, :replace) do
    if List.keymember?(headers, "vary", 0),
      do: headers,
      else: [{"vary", "Accept-Encoding"} | headers]
  end

  def add_vary(headers, :append) do
    {vary, rest} = Enum.split_with(headers, &(elem(&1, 0) == "vary"))
    [{"vary", "Accept-Encoding"} | vary] ++ rest
  end

  @doc "Whether the response headers allow compressing a body of `size` bytes."
  def compressible?(headers, size) do
    header(headers, "content-encoding") == "" and header(headers, "content-range") == "" and
      size >= @min_size and content_type_compressible?(header(headers, "content-type"))
  end

  defp header(headers, name) do
    case List.keyfind(headers, name, 0) do
      {_, value} -> value
      nil -> ""
    end
  end

  def content_type_compressible?(content_type) do
    content_type = content_type |> String.trim() |> String.downcase()

    content_type == "" or
      not (Enum.any?(@exclude_contains, &String.contains?(content_type, &1)) or
             String.starts_with?(content_type, @exclude_prefix))
  end

  @doc "Gzips `body`, with a content-dependent header comment when jitter is configured."
  def compress(body, jitter) do
    body = IO.iodata_to_binary(body)
    z = :zlib.open()

    try do
      :ok = :zlib.deflateInit(z, 6, :deflated, -15, 8, :default)
      deflated = :zlib.deflate(z, body, :finish)
      :ok = :zlib.deflateEnd(z)

      {flags, comment} =
        case comment(body, jitter) do
          nil -> {0, []}
          comment -> {0x10, [comment, 0]}
        end

      IO.iodata_to_binary([
        <<0x1F, 0x8B, 8, flags, 0::32, 0, 255>>,
        comment,
        deflated,
        <<:erlang.crc32(body)::little-32, rem(byte_size(body), 0x100000000)::little-32>>
      ])
    after
      :zlib.close(z)
    end
  end

  defp comment(_body, jitter) when jitter <= 0, do: nil

  defp comment(body, jitter) do
    padding = "Padding-" |> String.duplicate(1 + div(jitter, 8)) |> binary_part(0, jitter + 1)
    sample = binary_part(body, 0, min(byte_size(body), @jitter_sample))
    <<rng::32>> = <<:erlang.crc32(sample)::32>>
    binary_part(padding, 0, 1 + rem(Bitwise.bxor(rng, 0xAB0755DE), byte_size(padding) - 1))
  end
end
