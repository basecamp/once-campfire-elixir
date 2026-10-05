defmodule Campfire.HttpAdapter do
  @moduledoc """
  Bandit transport adapter preserving Rack's streaming gzip headers, with the front
  server's response handling (`Campfire.Front`) applied to everything sent.
  """
  @behaviour Plug.Conn.Adapter

  def send_resp(adapter, status, headers, body) do
    {status, headers, body, front_compressed} = Campfire.Front.respond(status, headers, body)

    if not front_compressed and
         List.keyfind(headers, "content-encoding", 0) == {"content-encoding", "gzip"} do
      {:ok, _, adapter} = Bandit.Adapter.send_chunked(adapter, status, headers)
      {:ok, _, adapter} = Bandit.Adapter.chunk(adapter, body)
      {:ok, _, adapter} = Bandit.Adapter.chunk(adapter, "")
      {:ok, nil, adapter}
    else
      Bandit.Adapter.send_resp(adapter, status, headers, body)
    end
  end

  def send_file(adapter, status, headers, path, offset, length) do
    encoding_error = Process.delete(:campfire_encoding_error)

    cond do
      is_binary(encoding_error) ->
        {status, headers, body, _} = Campfire.Front.respond(status, headers, encoding_error)
        Bandit.Adapter.send_resp(adapter, status, headers, body)

      status == 304 ->
        {status, headers, body, _} = Campfire.Front.respond(status, headers, "")
        Bandit.Adapter.send_resp(adapter, status, headers, body)

      List.keyfind(headers, "content-encoding", 0) == {"content-encoding", "gzip"} ->
        if Campfire.Front.stores?(status, headers) do
          # The front caches this response, so it needs the whole compressed body.
          body = gzip_file(path, offset, length, [], fn chunks, bytes -> [chunks, bytes] end)
          send_resp(adapter, status, headers, IO.iodata_to_binary(body))
        else
          {status, headers, _, _} = Campfire.Front.respond(status, headers, [], store: false)
          {:ok, _, adapter} = Bandit.Adapter.send_chunked(adapter, status, headers)

          adapter =
            gzip_file(path, offset, length, adapter, fn adapter, bytes ->
              {:ok, _, adapter} = Bandit.Adapter.chunk(adapter, bytes)
              adapter
            end)

          {:ok, _, adapter} = Bandit.Adapter.chunk(adapter, "")
          {:ok, nil, adapter}
        end

      true ->
        case Campfire.Front.respond_file(status, headers, path, offset, length) do
          {:body, status, headers, body} ->
            Bandit.Adapter.send_resp(adapter, status, headers, body)

          {:file, status, headers} ->
            Bandit.Adapter.send_file(adapter, status, headers, path, offset, length)
        end
    end
  end

  # Rack::Deflater's streaming gzip of a file: 16 KiB reads, each flushed, emitted in order.
  defp gzip_file(path, offset, length, acc, emit) do
    z = :zlib.open()

    try do
      :ok = :zlib.deflateInit(z, Campfire.HttpCompression.level(), :deflated, 31, 8, :default)

      File.open!(path, [:read, :binary], fn file ->
        {:ok, _} = :file.position(file, offset)
        remaining = if length == :all, do: File.stat!(path).size - offset, else: length
        {acc, first} = compress_file(file, remaining, z, acc, emit, true)
        bytes = IO.iodata_to_binary(:zlib.deflate(z, "", :finish))
        bytes = if first, do: Campfire.HttpCompression.timestamp_header(bytes), else: bytes
        :ok = :zlib.deflateEnd(z)
        emit.(acc, bytes)
      end)
    after
      :zlib.close(z)
    end
  end

  defp compress_file(_, remaining, _, acc, _, first) when remaining <= 0, do: {acc, first}

  defp compress_file(file, remaining, z, acc, emit, first) do
    case IO.binread(file, min(remaining, 16384)) do
      :eof ->
        {acc, first}

      bytes when is_binary(bytes) ->
        compressed = IO.iodata_to_binary(:zlib.deflate(z, bytes, :sync))

        compressed =
          if first, do: Campfire.HttpCompression.timestamp_header(compressed), else: compressed

        compress_file(file, remaining - byte_size(bytes), z, emit.(acc, compressed), emit, false)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read", path: "response file"
    end
  end

  defdelegate send_chunked(adapter, status, headers), to: Bandit.Adapter
  defdelegate chunk(adapter, body), to: Bandit.Adapter
  defdelegate read_req_body(adapter, opts), to: Bandit.Adapter
  defdelegate inform(adapter, status, headers), to: Bandit.Adapter

  def upgrade(adapter, protocol, opts) do
    Campfire.Front.upgraded()
    Bandit.Adapter.upgrade(adapter, protocol, opts)
  end

  defdelegate push(adapter, path, headers), to: Bandit.Adapter
  defdelegate get_peer_data(adapter), to: Bandit.Adapter
  defdelegate get_http_protocol(adapter), to: Bandit.Adapter
end
