defmodule Campfire.FrontTest do
  use ExUnit.Case, async: false
  alias Campfire.Front.{Cache, Config}

  defmodule App do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _) do
      case Campfire.Front.call(conn) do
        %Plug.Conn{halted: true} = conn -> respond(conn)
        conn -> respond(conn)
      end
    end

    defp respond(%Plug.Conn{halted: true} = conn), do: conn

    defp respond(conn) do
      :counters.add(:persistent_term.get(__MODULE__), 1, 1)

      case conn.request_path do
        "/public" ->
          conn
          |> put_resp_header("cache-control", "public, max-age=60")
          |> put_resp_header("etag", ~s("v1"))
          |> put_resp_content_type("text/css")
          |> send_resp(200, String.duplicate("body { color: red; }\n", 100))

        "/gzfile" ->
          conn
          |> put_resp_header("cache-control", "public, max-age=60")
          |> put_resp_header("content-encoding", "gzip")
          |> put_resp_header("vary", "Accept-Encoding")
          |> put_resp_content_type("image/webp")
          |> send_file(200, :persistent_term.get({__MODULE__, :file}))

        "/varying" ->
          conn
          |> put_resp_header("cache-control", "public, max-age=60")
          |> put_resp_header("vary", "Accept-Encoding")
          |> send_resp(200, "varies")

        "/private" ->
          conn |> put_resp_content_type("text/plain") |> send_resp(200, "private")

        "/image" ->
          conn |> put_resp_content_type("image/png") |> send_resp(200, :binary.copy(<<1>>, 4096))

        "/echo" ->
          body =
            Jason.encode!(%{
              remote_ip: conn.remote_ip |> :inet.ntoa() |> to_string(),
              forwarded_for: get_req_header(conn, "x-forwarded-for"),
              forwarded_proto: get_req_header(conn, "x-forwarded-proto"),
              forwarded: get_req_header(conn, "forwarded"),
              request_start: get_req_header(conn, "x-request-start")
            })

          send_resp(conn, 200, body)
      end
    end
  end

  defmodule LogHandler do
    def log(%{msg: {:string, message}, meta: meta}, %{config: %{pid: pid}}) do
      if meta[:domain] == [:campfire, :requests],
        do: send(pid, {:request_log, IO.iodata_to_binary(message)})
    end

    def log(_, _), do: :ok
  end

  setup do
    :persistent_term.put(App, :counters.new(1, []))
    Cache.clear()
    Config.load(%{"LOG_REQUESTS" => "false"})
    on_exit(fn -> Config.load() end)

    pid =
      start_supervised!(
        {Bandit,
         plug: App, port: 0, ip: :loopback, startup_log: false, http_options: [compress: false]}
      )

    {:ok, {_, port}} = ThousandIsland.listener_info(pid)
    %{port: port}
  end

  defp get(port, path, headers \\ [], method \\ :get) do
    url = ~c"http://127.0.0.1:#{port}#{path}"
    headers = Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    request =
      if method == :post, do: {url, headers, ~c"text/plain", ""}, else: {url, headers}

    {:ok, {{_, status, _}, headers, body}} =
      :httpc.request(method, request, [autoredirect: false], body_format: :binary)

    {status, Map.new(headers, fn {k, v} -> {to_string(k), to_string(v)} end), body}
  end

  defp app_calls, do: :counters.get(:persistent_term.get(App), 1)

  test "public responses are cached and served again without reaching the app", %{port: port} do
    assert {200, %{"x-cache" => "miss"}, body} = get(port, "/public")
    assert {200, %{"x-cache" => "hit"}, ^body} = get(port, "/public")
    assert {304, %{"x-cache" => "hit"}, ""} = get(port, "/public", [{"if-none-match", ~s("v1")}])
    assert app_calls() == 1

    assert {200, %{"x-cache" => "miss"}, _} = get(port, "/private")
    assert {200, %{"x-cache" => "miss"}, _} = get(port, "/private")
    assert app_calls() == 3

    assert {200, %{"x-cache" => "bypass"}, _} = get(port, "/public", [{"range", "bytes=0-1"}])
  end

  test "responses that vary are served to requests with the same varying values", %{
    port: port
  } do
    gzip = [{"accept-encoding", "gzip"}]
    assert {200, %{"x-cache" => "miss"}, "varies"} = get(port, "/varying", gzip)
    assert {200, %{"x-cache" => "hit"}, "varies"} = get(port, "/varying", gzip)
    assert {200, %{"x-cache" => "miss"}, "varies"} = get(port, "/varying")
    assert app_calls() == 2
  end

  test "a cached file the app gzips while streaming is served whole", %{port: port} do
    path = Path.join(System.tmp_dir!(), "front-test-#{System.unique_integer([:positive])}")
    File.write!(path, :crypto.strong_rand_bytes(40_000))
    on_exit(fn -> File.rm(path) end)
    :persistent_term.put({App, :file}, path)
    gzip = [{"accept-encoding", "gzip"}]

    assert {200, %{"x-cache" => "miss"}, first} = get(port, "/gzfile", gzip)
    assert {200, %{"x-cache" => "hit"}, ^first} = get(port, "/gzfile", gzip)
    assert :zlib.gunzip(first) == File.read!(path)
    assert app_calls() == 1
  end

  test "compressible bodies are gzipped identically for a gzip client", %{port: port} do
    headers = [{"accept-encoding", "gzip"}]

    assert {200, %{"content-encoding" => "gzip", "vary" => vary}, first} =
             get(port, "/public", headers)

    assert vary =~ "Accept-Encoding"

    assert {200, %{"x-cache" => "hit", "content-encoding" => "gzip"}, ^first} =
             get(port, "/public", headers)

    assert :zlib.gunzip(first) == String.duplicate("body { color: red; }\n", 100)
    # The jitter comment is present in the gzip header.
    assert <<0x1F, 0x8B, 8, 0x10, _::binary>> = first

    assert {200, headers, _} = get(port, "/public")
    refute Map.has_key?(headers, "content-encoding")
    assert {200, headers, _} = get(port, "/image", [{"accept-encoding", "gzip"}])
    refute Map.has_key?(headers, "content-encoding")
  end

  test "the app sees requests as Thruster's loopback upstream", %{port: port} do
    {200, _, body} =
      get(port, "/echo", [{"x-forwarded-for", "203.0.113.9"}, {"forwarded", "for=1.2.3.4"}])

    echo = Jason.decode!(body)
    assert echo["remote_ip"] == "127.0.0.1"
    assert echo["forwarded_for"] == ["203.0.113.9, 127.0.0.1"]
    assert echo["forwarded_proto"] == ["http"]
    assert echo["forwarded"] == []
    assert ["t=" <> _] = echo["request_start"]

    Config.load(%{"LOG_REQUESTS" => "false", "FORWARD_HEADERS" => "false"})
    {200, _, body} = get(port, "/echo", [{"x-forwarded-for", "203.0.113.9"}])
    assert Jason.decode!(body)["forwarded_for"] == ["127.0.0.1"]
  end

  test "request bodies over MAX_REQUEST_BODY are refused", %{port: port} do
    Config.load(%{"LOG_REQUESTS" => "false", "MAX_REQUEST_BODY" => "4"})

    {:ok, {{_, 413, _}, _, _}} =
      :httpc.request(
        :post,
        {~c"http://127.0.0.1:#{port}/echo", [], ~c"text/plain", "too large"},
        [],
        []
      )

    assert app_calls() == 0
  end

  test "request log lines are written only with LOG_REQUESTS", %{port: port} do
    Campfire.Front.setup_logging(Config.load(%{"LOG_REQUESTS" => "false"}))
    :ok = :logger.add_handler(:front_test, LogHandler, %{config: %{pid: self()}})
    on_exit(fn -> :logger.remove_handler(:front_test) end)

    get(port, "/private")
    refute_receive {:request_log, _}, 100

    Config.load(%{"LOG_REQUESTS" => "true"})
    get(port, "/private?a=1", [{"user-agent", "test-agent"}])
    assert_receive {:request_log, line}

    assert %{
             "msg" => "Request",
             "path" => "/private",
             "query" => "a=1",
             "status" => 200,
             "method" => "GET",
             "cache" => "miss",
             "user_agent" => "test-agent",
             "resp_content_length" => 7,
             "proto" => "HTTP/1.1"
           } = Jason.decode!(line)
  end
end
