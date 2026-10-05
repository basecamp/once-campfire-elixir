defmodule Campfire.Front do
  @moduledoc """
  The in-process front server that replaced Thruster: what Thruster did between the client
  and the app, applied around each Bandit request.

  Request side (`call/1`): the `MAX_REQUEST_BODY` limit, `X-Request-Start`, the
  `X-Forwarded-*` headers `httputil.ReverseProxy` set, and the response cache lookup.
  The app keeps seeing each request as Thruster's loopback upstream request, so its Rails
  proxy and remote-IP rules apply unchanged.

  Response side (`respond/3`, called by `Campfire.HttpAdapter`): cache storage, `X-Cache`,
  compression and the request log line. Per-request state lives in the process dictionary,
  since Bandit's adapter state cannot carry it.
  """
  import Plug.Conn
  alias Campfire.Front.{Cache, Config, Gzip}
  @key :campfire_front
  @loopback {127, 0, 0, 1}

  defmodule BodyTooLarge do
    @moduledoc "A request body read past `MAX_REQUEST_BODY` (Thruster's `http.MaxBytesReader`)."
    defexception message: "request body exceeds MAX_REQUEST_BODY", plug_status: 413
  end

  @doc """
  Counts body bytes read for the current request against `MAX_REQUEST_BODY`, raising
  `BodyTooLarge` past it. `Content-Length` is checked up front; this also covers chunked and
  length-less bodies.
  """
  def body_read(bytes) do
    case Process.get(@key) do
      %{config: %{max_request_body: limit}} when limit > 0 ->
        total = Process.get(:campfire_front_body_read, 0) + bytes
        Process.put(:campfire_front_body_read, total)
        if total > limit, do: raise(BodyTooLarge)

      _ ->
        :ok
    end
  end

  @doc "The empty 413 the front sends for an oversized body."
  def too_large(conn), do: conn |> put_resp_headers([]) |> send_resp(413, "") |> halt()

  def call(%Plug.Conn{adapter: {Bandit.Adapter, adapter}} = conn) do
    config = Config.get()
    started = System.monotonic_time()
    log = if config.log_requests, do: log_fields(conn)

    conn =
      %{conn | adapter: {Campfire.HttpAdapter, adapter}}
      |> as_proxied_http1()

    front = %{
      config: config,
      started: started,
      log: log,
      cache: :bypass,
      gzip: config.gzip_enabled and Gzip.accepts?(conn.method, header(conn, "accept-encoding")),
      user_specific: config.gzip_disable_on_auth and Gzip.user_specific_request?(conn.req_headers)
    }

    Process.put(@key, front)
    Process.delete(:campfire_front_body_read)

    cond do
      too_large?(conn, config.max_request_body) ->
        too_large(conn)

      Cache.cacheable_request?(conn) ->
        now = System.monotonic_time(:millisecond)
        base = Cache.base_key(conn)

        case Cache.lookup(conn, base, now) do
          nil ->
            Process.put(@key, %{front | cache: {:miss, request(conn), base, now}})
            forward(conn, config)

          entry ->
            Process.put(@key, %{front | cache: {:hit, entry}})
            hit(conn, entry)
        end

      true ->
        forward(conn, config)
    end
  end

  def call(conn), do: conn

  # A stored response, or 304 when the request already holds its ETag (`WriteCachedResponse`).
  defp hit(conn, {_, _, _, status, headers, body, _, _}) do
    etag = Cache.header(headers, "etag")

    not_modified =
      etag != "" and
        conn
        |> header("if-none-match")
        |> String.split(",")
        |> Enum.any?(&(String.trim(&1) == etag))

    {status, body} = if not_modified, do: {304, ""}, else: {status, body}

    %{conn | resp_headers: [{"x-cache", "hit"} | headers]}
    |> send_resp(status, body)
    |> halt()
  end

  defp put_resp_headers(conn, headers), do: %{conn | resp_headers: headers}

  defp too_large?(_conn, limit) when limit <= 0, do: false

  defp too_large?(conn, limit) do
    case Integer.parse(header(conn, "content-length")) do
      {length, ""} -> length > limit
      _ -> false
    end
  end

  # The request as the app saw it from Thruster: an HTTP/2 request's authority as `Host`,
  # X-Request-Start, and `setXForwarded` (the client's own X-Forwarded-* kept only with
  # FORWARD_HEADERS), arriving from the loopback proxy.
  defp forward(conn, config) do
    peer = conn.remote_ip |> :inet.ntoa() |> to_string()

    prior =
      if config.forward_headers,
        do: Enum.join(get_req_header(conn, "x-forwarded-for"), ", "),
        else: ""

    incoming_host = header(conn, "x-forwarded-host")
    incoming_proto = header(conn, "x-forwarded-proto")

    host =
      if config.forward_headers and incoming_host != "",
        do: incoming_host,
        else: header(conn, "host")

    proto =
      cond do
        config.forward_headers and incoming_proto != "" -> incoming_proto
        conn.scheme == :https -> "https"
        true -> "http"
      end

    headers =
      conn.req_headers
      |> Enum.reject(fn {name, _} ->
        name in ~w(forwarded x-forwarded-for x-forwarded-host x-forwarded-proto)
      end)

    headers = [
      {"x-forwarded-for", if(prior == "", do: peer, else: prior <> ", " <> peer)},
      {"x-forwarded-host", host},
      {"x-forwarded-proto", proto}
      | headers
    ]

    headers =
      if List.keymember?(headers, "x-request-start", 0) and header(conn, "x-request-start") != "",
        do: headers,
        else: [{"x-request-start", "t=#{System.os_time(:millisecond)}"} | headers]

    %{conn | req_headers: headers, remote_ip: @loopback}
  end

  defp as_proxied_http1(conn) do
    if get_http_protocol(conn) == :"HTTP/2" and header(conn, "host") == "" do
      default = if conn.scheme == :https, do: 443, else: 80
      authority = if conn.port == default, do: conn.host, else: "#{conn.host}:#{conn.port}"
      %{conn | req_headers: [{"host", authority} | conn.req_headers]}
    else
      conn
    end
  end

  defp request(conn),
    do: %{
      method: conn.method,
      request_path: conn.request_path,
      query_string: conn.query_string,
      host: conn.host,
      req_headers: conn.req_headers
    }

  @doc """
  Applies the front's response handling to a response the app is sending. Returns the
  status, headers and body to write and whether the body was compressed here.
  """
  def respond(status, headers, body, opts \\ []) do
    case Process.delete(@key) do
      nil ->
        {status, headers, body, false}

      front when opts == [] ->
        finish(front, status, headers, body)

      front ->
        # A streamed body is not available to store: pass it through uncached.
        front = if opts[:store] == false, do: %{front | cache: :uncached}, else: front
        finish(front, status, headers, body)
    end
  end

  @doc "Whether the front will store this response in its cache."
  def stores?(status, headers) do
    match?(%{cache: {:miss, _, _, _}}, Process.get(@key)) and
      Cache.lifetime(status, headers) != nil
  end

  defp finish(front, status, headers, body, logged_bytes \\ nil) do
    config = front.config

    {headers, merge, entry} =
      case front.cache do
        :bypass ->
          {[{"x-cache", "bypass"} | headers], :append, nil}

        :uncached ->
          {[{"x-cache", "miss"} | headers], :replace, nil}

        {:hit, entry} ->
          {headers, :replace, entry}

        {:miss, request, base, now} ->
          headers =
            case Cache.lifetime(status, headers) do
              nil ->
                headers

              lifetime ->
                headers = List.keydelete(headers, "set-cookie", 0)
                Cache.store(request, base, status, headers, body, lifetime, now, config)
                headers
            end

          {[{"x-cache", "miss"} | headers], :replace, nil}
      end

    {headers, body, compressed} =
      if config.gzip_enabled,
        do: compress(front, status, Gzip.add_vary(headers, merge), body, entry),
        else: {headers, body, false}

    headers = suppress_bodiless(status, headers)
    if front.log, do: log(front, status, headers, logged_bytes || IO.iodata_length(body))
    {status, headers, body, compressed}
  end

  defp compress(front, status, headers, body, entry) do
    vetoed =
      front.user_specific or
        (front.config.gzip_disable_on_auth and Gzip.user_specific_response?(headers))

    if front.gzip and status >= 200 and not vetoed and
         Gzip.compressible?(headers, IO.iodata_length(body)) do
      gzipped =
        case entry do
          {_, _, _, _, _, _, _, gzipped} when is_binary(gzipped) and status != 304 ->
            gzipped

          _ ->
            gzipped = Gzip.compress(body, front.config.gzip_jitter)
            if entry && status != 304, do: Cache.put_gzip(entry, gzipped)
            gzipped
        end

      headers =
        headers
        |> List.keydelete("content-length", 0)
        |> List.keydelete("accept-ranges", 0)

      {[{"content-encoding", "gzip"} | headers], gzipped, true}
    else
      {headers, body, false}
    end
  end

  @doc """
  Handling for a file response: `{:body, status, headers, body}` when the file is cached or
  compressed here, otherwise `{:file, status, headers}` to send the file as is.
  """
  def respond_file(status, headers, path, offset, length) do
    case Process.delete(@key) do
      nil ->
        {:file, status, headers}

      front ->
        size = if length == :all, do: File.stat!(path).size - offset, else: length

        cacheable =
          match?({:miss, _, _, _}, front.cache) and Cache.lifetime(status, headers) != nil and
            size <= front.config.max_cache_item_size

        if cacheable or (front.gzip and Gzip.compressible?(headers, size)) do
          {:ok, data} = :file.read_file(path)
          body = binary_part(data, offset, size)
          {status, headers, body, _} = finish(front, status, headers, body)
          {:body, status, headers, body}
        else
          {status, headers, _, _} = finish(front, status, headers, [], size)
          {:file, status, headers}
        end
    end
  end

  @doc "A websocket upgrade ends the front's part of the request."
  def upgraded do
    # A websocket outlives the request: Campfire.DB checks for outside commits on every lookup.
    Process.delete(:campfire_request)

    case Process.delete(@key) do
      %{log: log} = front when not is_nil(log) -> log(front, 101, [], 0)
      _ -> :ok
    end
  end

  defp suppress_bodiless(304, headers),
    do:
      Enum.reject(headers, fn {name, _} ->
        name in ~w(content-type content-length transfer-encoding)
      end)

  defp suppress_bodiless(status, headers) when status in 100..199 or status == 204,
    do: Enum.reject(headers, fn {name, _} -> name in ~w(content-length transfer-encoding) end)

  defp suppress_bodiless(_, headers), do: headers

  # Thruster's request log line (`logging_handler.go`).
  defp log_fields(conn) do
    forwarded = conn |> get_req_header("x-forwarded-for") |> Enum.join(", ")

    remote =
      if forwarded == "" do
        %{address: address, port: port} = get_peer_data(conn)
        "#{:inet.ntoa(address)}:#{port}"
      else
        forwarded
      end

    content_length =
      case Integer.parse(header(conn, "content-length")) do
        {length, ""} -> length
        _ -> 0
      end

    [
      path: conn.request_path,
      method: conn.method,
      req_content_length: content_length,
      req_content_type: header(conn, "content-type"),
      remote_addr: remote,
      user_agent: header(conn, "user-agent"),
      query: conn.query_string,
      proto: if(get_http_protocol(conn) == :"HTTP/2", do: "HTTP/2.0", else: "HTTP/1.1")
    ]
  end

  defp log(front, status, headers, bytes) do
    fields = front.log

    duration =
      System.convert_time_unit(System.monotonic_time() - front.started, :native, :millisecond)

    line =
      Jason.encode_to_iodata!(
        Jason.OrderedObject.new(
          time: DateTime.utc_now() |> DateTime.to_iso8601(),
          level: "INFO",
          msg: "Request",
          path: fields[:path],
          status: status,
          dur: duration,
          method: fields[:method],
          req_content_length: fields[:req_content_length],
          req_content_type: fields[:req_content_type],
          resp_content_length: bytes,
          resp_content_type: Cache.header(headers, "content-type"),
          remote_addr: fields[:remote_addr],
          user_agent: fields[:user_agent],
          cache: Cache.header(headers, "x-cache"),
          query: fields[:query],
          proto: fields[:proto]
        )
      )

    :logger.info(IO.iodata_to_binary(line), %{domain: [:campfire, :requests]})
  end

  @doc "Routes request log lines to their own stdout handler, without the default formatting."
  def setup_logging(config \\ Config.get()) do
    filter = {&:logger_filters.domain/2, {:stop, :sub, [:campfire, :requests]}}
    _ = :logger.add_handler_filter(:default, :campfire_requests, filter)

    if config.log_requests do
      :logger.add_handler(:campfire_requests, :logger_std_h, %{
        level: :info,
        filter_default: :stop,
        filters: [
          requests: {&:logger_filters.domain/2, {:log, :sub, [:campfire, :requests]}}
        ],
        formatter: {:logger_formatter, %{template: [:msg, "\n"], single_line: false}}
      })
    end

    :ok
  end

  defp header(conn, name) do
    case get_req_header(conn, name) do
      [value | _] -> value
      [] -> ""
    end
  end
end
