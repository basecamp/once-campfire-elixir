defmodule Campfire.HttpAdapter do
  @moduledoc "Bandit transport adapter preserving Rack's streaming gzip headers."
  @behaviour Plug.Conn.Adapter

  def send_resp(adapter, status, headers, body) do
    if List.keyfind(headers, "content-encoding", 0) == {"content-encoding", "gzip"} do
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
        Bandit.Adapter.send_resp(adapter, status, headers, encoding_error)

      status == 304 ->
        Bandit.Adapter.send_resp(adapter, status, headers, "")

      List.keyfind(headers, "content-encoding", 0) == {"content-encoding", "gzip"} ->
        {:ok, _, adapter} = Bandit.Adapter.send_chunked(adapter, status, headers)
        z = :zlib.open()

        try do
          :ok = :zlib.deflateInit(z, Campfire.HttpCompression.level(), :deflated, 31, 8, :default)

          File.open!(path, [:read, :binary], fn file ->
            {:ok, _} = :file.position(file, offset)
            remaining = if length == :all, do: File.stat!(path).size - offset, else: length
            {adapter, first} = compress_file(file, remaining, z, adapter, true)
            bytes = IO.iodata_to_binary(:zlib.deflate(z, "", :finish))
            bytes = if first, do: Campfire.HttpCompression.timestamp_header(bytes), else: bytes
            {:ok, _, adapter} = Bandit.Adapter.chunk(adapter, bytes)
            {:ok, _, adapter} = Bandit.Adapter.chunk(adapter, "")
            :ok = :zlib.deflateEnd(z)
            {:ok, nil, adapter}
          end)
        after
          :zlib.close(z)
        end

      true ->
        Bandit.Adapter.send_file(adapter, status, headers, path, offset, length)
    end
  end

  defp compress_file(_, remaining, _, adapter, first) when remaining <= 0, do: {adapter, first}

  defp compress_file(file, remaining, z, adapter, first) do
    case IO.binread(file, min(remaining, 16384)) do
      :eof ->
        {adapter, first}

      bytes when is_binary(bytes) ->
        compressed = IO.iodata_to_binary(:zlib.deflate(z, bytes, :sync))

        compressed =
          if first, do: Campfire.HttpCompression.timestamp_header(compressed), else: compressed

        {:ok, _, adapter} = Bandit.Adapter.chunk(adapter, compressed)
        compress_file(file, remaining - byte_size(bytes), z, adapter, false)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read", path: "response file"
    end
  end

  defdelegate send_chunked(adapter, status, headers), to: Bandit.Adapter
  defdelegate chunk(adapter, body), to: Bandit.Adapter
  defdelegate read_req_body(adapter, opts), to: Bandit.Adapter
  defdelegate inform(adapter, status, headers), to: Bandit.Adapter
  defdelegate upgrade(adapter, protocol, opts), to: Bandit.Adapter
  defdelegate push(adapter, path, headers), to: Bandit.Adapter
  defdelegate get_peer_data(adapter), to: Bandit.Adapter
  defdelegate get_http_protocol(adapter), to: Bandit.Adapter
end
