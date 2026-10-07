defmodule Campfire.Network do
  @moduledoc "Pinned-address HTTP requests for webhook, OpenGraph and push delivery."
  def public_ip?(ip), do: Campfire.IPPolicy.public?(ip)

  def resolve(host, guard \\ :public) do
    host = String.to_charlist(host)

    ips =
      for family <- [:inet, :inet6],
          {:ok, addresses} <- [:inet.getaddrs(host, family)],
          address <- addresses,
          do: address

    ips = if guard == :none, do: ips, else: Enum.filter(ips, &public_ip?/1)

    if ips != [],
      do: {:ok, hd(ips)},
      else: {:error, :unsafe_or_unresolved_host}
  end

  def request(url, method, headers \\ [], body \\ "", opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 7000)

    with {:ok, uri} <- Campfire.HttpURL.parse(url),
         true <- uri.scheme in ["http", "https"] && is_binary(uri.host),
         {:ok, ip} <- resolve(uri.host, Keyword.get(opts, :guard, :public)),
         {:ok, socket, transport} <- connect(uri, ip, timeout) do
      try do
        path =
          if(uri.path in [nil, ""], do: "/", else: uri.path) <>
            if(uri.query, do: "?" <> uri.query, else: "")

        host = uri.host <> if(uri.port in [80, 443], do: "", else: ":#{uri.port}")

        supplied = Enum.map(headers, fn {key, _} -> String.downcase(key) end)
        decode? = "accept-encoding" not in supplied && "range" not in supplied

        headers =
          if decode?,
            do: [{"Accept-Encoding", "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"} | headers],
            else: headers

        headers = [
          {"Host", host},
          {"Connection", "close"},
          {"Content-Length", to_string(byte_size(body))} | headers
        ]

        request =
          String.upcase(to_string(method)) <>
            " " <>
            path <>
            " HTTP/1.1\r\n" <>
            Enum.map_join(headers, "", fn {name, value} -> name <> ": " <> value <> "\r\n" end) <>
            "\r\n" <> body

        :ok = transport.send(socket, request)

        result =
          receive_response(
            socket,
            transport,
            timeout,
            "",
            method,
            Keyword.get(opts, :max_body_size, :infinity)
          )

        if decode?,
          do: decode_response(result, Keyword.get(opts, :max_body_size, :infinity)),
          else: result
      after
        transport.close(socket)
      end
    else
      false -> {:error, :invalid_url}
      error -> error
    end
  rescue
    error -> {:error, error}
  end

  defp decode_response({:ok, status, headers, body} = result, limit) when is_binary(body) do
    encoding = String.downcase(headers["content-encoding"] || "")

    if !headers["content-range"] && encoding in ["gzip", "x-gzip", "deflate", "x-deflate"] do
      decoded =
        cond do
          body == "" -> ""
          encoding in ["gzip", "x-gzip"] -> :zlib.gunzip(body)
          true -> inflate(body)
        end

      if exceeds?(byte_size(decoded), limit) do
        {:error, :body_too_large}
      else
        headers = Map.delete(headers, "content-encoding")

        headers =
          if headers["content-length"],
            do: Map.put(headers, "content-length", to_string(byte_size(decoded))),
            else: headers

        {:ok, status, headers, decoded}
      end
    else
      result
    end
  end

  defp decode_response(result, _), do: result

  defp inflate(body) do
    :zlib.uncompress(body)
  rescue
    ErlangError ->
      stream = :zlib.open()

      try do
        :ok = :zlib.inflateInit(stream, -15)
        IO.iodata_to_binary(:zlib.inflate(stream, body))
      after
        :zlib.close(stream)
      end
  end

  defp connect(%{scheme: "http", port: port}, ip, timeout) do
    family = if tuple_size(ip) == 8, do: :inet6, else: :inet

    case :gen_tcp.connect(ip, port, [:binary, family, active: false, packet: :raw], timeout) do
      {:ok, socket} -> {:ok, socket, :gen_tcp}
      error -> error
    end
  end

  defp connect(%{scheme: "https", port: port, host: host}, ip, timeout) do
    options = [
      :binary,
      active: false,
      verify: :verify_peer,
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    options =
      case System.get_env("SSL_CERT_FILE") do
        path when is_binary(path) and path != "" ->
          [{:cacertfile, String.to_charlist(path)} | options]

        _ ->
          [{:cacerts, :public_key.cacerts_get()} | options]
      end

    case :ssl.connect(ip, port, options, timeout) do
      {:ok, socket} -> {:ok, socket, :ssl}
      error -> error
    end
  end

  defp receive_response(socket, transport, timeout, buffer, method, limit) do
    if String.contains?(buffer, "\r\n\r\n") do
      [head, body] = String.split(buffer, "\r\n\r\n", parts: 2)
      [status | lines] = String.split(head, "\r\n")
      [_, code | _] = String.split(status, " ")

      {headers, _last} =
        Enum.reduce(lines, {%{}, nil}, fn line, {headers, last} ->
          if String.starts_with?(line, [" ", "\t"]) && last do
            {Map.update!(headers, last, &(&1 <> " " <> String.trim(line))), last}
          else
            [name, value] = String.split(line, ":", parts: 2)
            name = String.downcase(name)
            value = String.trim(value)
            {Map.update(headers, name, value, &(&1 <> ", " <> value)), name}
          end
        end)

      code = String.to_integer(code)

      cond do
        code in 100..199 && code != 101 ->
          receive_response(socket, transport, timeout, body, method, limit)

        method == :head ->
          {:ok, code, headers, ""}

        code in [204, 304] ->
          {:ok, code, headers, nil}

        true ->
          case receive_body(socket, transport, timeout, body, headers, limit) do
            {:ok, body} -> {:ok, code, headers, body}
            error -> error
          end
      end
    else
      case transport.recv(socket, 0, timeout) do
        {:ok, data} -> receive_response(socket, transport, timeout, buffer <> data, method, limit)
        error -> error
      end
    end
  end

  defp receive_body(socket, transport, timeout, body, headers, limit) do
    cond do
      String.downcase(headers["transfer-encoding"] || "") == "chunked" ->
        receive_chunks(socket, transport, timeout, body, [], 0, limit)

      is_binary(headers["content-length"]) ->
        length = String.to_integer(headers["content-length"])

        if exceeds?(length, limit),
          do: {:error, :body_too_large},
          else: read_exact(socket, transport, timeout, body, length)

      true ->
        read_to_close(socket, transport, timeout, body, limit)
    end
  end

  defp exceeds?(_, :infinity), do: false
  defp exceeds?(size, limit), do: size > limit

  defp read_exact(_, _, _, body, length) when byte_size(body) >= length,
    do: {:ok, binary_part(body, 0, length)}

  defp read_exact(socket, transport, timeout, body, length) do
    case transport.recv(socket, 0, timeout) do
      {:ok, data} -> read_exact(socket, transport, timeout, body <> data, length)
      {:error, :closed} -> {:ok, body}
      error -> error
    end
  end

  defp read_to_close(socket, transport, timeout, body, limit) do
    if exceeds?(byte_size(body), limit) do
      {:error, :body_too_large}
    else
      case transport.recv(socket, 0, timeout) do
        {:ok, data} -> read_to_close(socket, transport, timeout, body <> data, limit)
        {:error, :closed} -> {:ok, body}
        error -> error
      end
    end
  end

  defp receive_chunks(socket, transport, timeout, buffer, parts, size, limit) do
    with {:ok, line, buffer} <- line(socket, transport, timeout, buffer),
         {length, _} <- Integer.parse(hd(String.split(line, ";")), 16),
         true <- length >= 0 && !exceeds?(size + length, limit) do
      if length == 0 do
        {:ok, IO.iodata_to_binary(parts)}
      else
        with {:ok, buffer} <- at_least(socket, transport, timeout, buffer, length + 2),
             <<chunk::binary-size(^length), "\r\n", rest::binary>> <- buffer do
          receive_chunks(socket, transport, timeout, rest, [parts, chunk], size + length, limit)
        else
          error -> error
        end
      end
    else
      false -> {:error, :body_too_large}
      error -> error
    end
  end

  defp line(socket, transport, timeout, buffer) do
    case :binary.split(buffer, "\r\n") do
      [line, rest] ->
        {:ok, line, rest}

      _ ->
        case transport.recv(socket, 0, timeout) do
          {:ok, data} -> line(socket, transport, timeout, buffer <> data)
          error -> error
        end
    end
  end

  defp at_least(_, _, _, buffer, length) when byte_size(buffer) >= length, do: {:ok, buffer}

  defp at_least(socket, transport, timeout, buffer, length) do
    case transport.recv(socket, 0, timeout) do
      {:ok, data} -> at_least(socket, transport, timeout, buffer <> data, length)
      error -> error
    end
  end
end
