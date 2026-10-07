defmodule Campfire.WebSocketTimeoutTest do
  use ExUnit.Case, async: true

  defmodule QuietSocket do
    @behaviour WebSock
    def init(state), do: {:ok, state}
    def handle_in(_, state), do: {:ok, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule Upgrade do
    def init(options), do: options

    def call(conn, _) do
      conn
      |> Plug.Conn.upgrade_adapter(
        :websocket,
        {QuietSocket, nil, Campfire.Cable.websocket_options()}
      )
      |> Plug.Conn.halt()
    end
  end

  test "receive-only cable connections outlive the server read timeout" do
    {:ok, server} =
      Bandit.start_link(
        plug: Upgrade,
        port: 0,
        ip: :loopback,
        startup_log: false,
        thousand_island_options: [read_timeout: 200]
      )

    {:ok, {_, port}} = ThousandIsland.listener_info(server)
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])

    :ok =
      :gen_tcp.send(socket, [
        "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
      ])

    {:ok, response} = :gen_tcp.recv(socket, 0, 5_000)
    assert response =~ "101 Switching Protocols"
    assert :gen_tcp.recv(socket, 0, 700) == {:error, :timeout}
  end
end
