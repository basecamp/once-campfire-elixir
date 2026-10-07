defmodule Campfire.NetworkTest do
  use ExUnit.Case, async: true
  alias Campfire.Network

  test "public endpoint resolution rejects local, mapped, documentation and link-local addresses" do
    for ip <- [
          {127, 0, 0, 1},
          {10, 1, 2, 3},
          {172, 16, 0, 1},
          {192, 168, 0, 1},
          {169, 254, 169, 254},
          {100, 64, 0, 1},
          {192, 0, 2, 1},
          {203, 0, 113, 1},
          {0, 0, 0, 0, 0, 0, 0, 1},
          {0, 0, 0, 0, 0, 65_535, 32_512, 1},
          {0xFC00, 0, 0, 0, 0, 0, 0, 1},
          {0xFE80, 0, 0, 0, 0, 0, 0, 1}
        ],
        do: refute(Network.public_ip?(ip))

    assert Network.public_ip?({8, 8, 8, 8})
    assert Network.public_ip?({0x2606, 0x4700, 0x4700, 0, 0, 0, 0, 0x1111})
    assert Network.resolve("localhost") == {:error, :unsafe_or_unresolved_host}
  end

  test "webhook HTTP can use an explicitly permitted local sink and decodes chunked responses" do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listen)

    task =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listen)
        {:ok, request} = :gen_tcp.recv(socket, 0, 5000)
        assert request =~ "POST /hook?x=1 HTTP/1.1"
        assert request =~ "Content-Type: application/json"

        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n"
        )

        :gen_tcp.close(socket)
      end)

    assert {:ok, 200, %{"content-type" => "text/plain"}, "hello world"} =
             Network.request(
               "http://127.0.0.1:#{port}/hook?x=1",
               :post,
               [{"Content-Type", "application/json"}],
               "{}",
               guard: :none
             )

    Task.await(task)
    :gen_tcp.close(listen)
  end

  test "HEAD reads metadata without waiting for the declared response body" do
    assert {:ok, 200, %{"content-length" => "9000000"}, ""} =
             response("HTTP/1.1 200 OK\r\nContent-Length: 9000000\r\n\r\n", :head,
               max_body_size: 10
             )
  end

  test "OpenGraph body limits reject excessive length before reading the body" do
    assert {:error, :body_too_large} =
             response("HTTP/1.1 200 OK\r\nContent-Length: 11\r\n\r\n", :get, max_body_size: 10)
  end

  test "body limits count decoded chunks and decode split frames" do
    assert {:ok, 200, _, "helloworld"} =
             response(
               "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n5\r\nworld\r\n0\r\n\r\n",
               :get,
               max_body_size: 10
             )

    assert {:error, :body_too_large} =
             response(
               "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n",
               :get,
               max_body_size: 10
             )
  end

  test "body limits cover responses without a declared length" do
    assert {:error, :body_too_large} =
             response("HTTP/1.1 200 OK\r\n\r\n01234567890", :get, max_body_size: 10)
  end

  test "informational headers precede the final response and body" do
    assert {:ok, 200, %{"content-length" => "5"}, "hello"} =
             response(
               "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 103 Early Hints\r\nLink: </asset>\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
               :get,
               []
             )
  end

  test "bodyless statuses preserve Net::HTTP nil bodies without reading advertised bytes" do
    for code <- [204, 304] do
      assert {:ok, ^code, _, nil} =
               response("HTTP/1.1 #{code} fixture\r\nContent-Length: 5000000\r\n\r\n", :get,
                 max_body_size: 10
               )
    end
  end

  test "repeated response fields use Net::HTTP comma joining" do
    assert {:ok, 200, %{"x-value" => "one, two", "content-length" => "0"}, ""} =
             response(
               "HTTP/1.1 200 OK\r\nX-Value: one\r\nX-Value: two\r\nContent-Length: 0\r\n\r\n",
               :get,
               []
             )
  end

  defp response(bytes, method, options) do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listen)

    task =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listen)
        {:ok, _} = :gen_tcp.recv(socket, 0, 5000)
        # Send individual octets so the client cannot assume frame boundaries.
        for <<byte <- bytes>>, do: :gen_tcp.send(socket, <<byte>>)
        :gen_tcp.close(socket)
      end)

    result =
      Network.request("http://127.0.0.1:#{port}/", method, [], "", [guard: :none] ++ options)

    Task.await(task)
    :gen_tcp.close(listen)
    result
  end
end
