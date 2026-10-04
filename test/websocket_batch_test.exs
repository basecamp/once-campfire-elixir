defmodule Campfire.WebSocketBatchTest do
  use ExUnit.Case, async: true

  defmodule Pusher do
    @behaviour WebSock
    def init(frames), do: {:push, frames, frames}
    def handle_in(_, state), do: {:ok, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule Upgrade do
    def init(opts), do: opts

    def call(conn, frames),
      do:
        Plug.Conn.upgrade_adapter(conn, :websocket, {Pusher, frames, [compress: false]})
        |> Plug.Conn.halt()
  end

  test "pushed frames written together arrive intact and in order" do
    big = String.duplicate("x", 70_000)

    frames = [
      {:text, "one"},
      {:binary, <<0, 1, 2>>},
      {:text, String.duplicate("é", 200)},
      {:text, big}
    ]

    {:ok, server} =
      Bandit.start_link(plug: {Upgrade, frames}, port: 0, ip: :loopback, startup_log: false)

    {:ok, {_, port}} = ThousandIsland.listener_info(server)
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false])

    :ok =
      :gen_tcp.send(socket, [
        "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
      ])

    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
    [head, rest] = :binary.split(response, "\r\n\r\n")
    assert head =~ "101 Switching Protocols"
    assert read_frames(socket, rest, length(frames)) == frames
  end

  defp read_frames(_, _, 0), do: []

  defp read_frames(socket, buffer, count) do
    case parse(buffer) do
      {:ok, frame, rest} -> [frame | read_frames(socket, rest, count - 1)]
      :more -> read_frames(socket, buffer <> recv!(socket), count)
    end
  end

  defp recv!(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0, 5000)
    data
  end

  defp parse(
         <<1::1, 0::3, opcode::4, 0::1, 127::7, size::64, data::binary-size(size), rest::binary>>
       ),
       do: {:ok, {type(opcode), data}, rest}

  defp parse(
         <<1::1, 0::3, opcode::4, 0::1, 126::7, size::16, data::binary-size(size), rest::binary>>
       ),
       do: {:ok, {type(opcode), data}, rest}

  defp parse(<<1::1, 0::3, opcode::4, 0::1, size::7, data::binary-size(size), rest::binary>>)
       when size < 126,
       do: {:ok, {type(opcode), data}, rest}

  defp parse(_), do: :more

  defp type(1), do: :text
  defp type(2), do: :binary

  defmodule Quiet do
    @behaviour WebSock
    def init(state), do: {:ok, state}
    def handle_in(_, state), do: {:ok, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule QuietUpgrade do
    def init(opts), do: opts

    def call(conn, _),
      do:
        Plug.Conn.upgrade_adapter(
          conn,
          :websocket,
          {Quiet, nil, Campfire.Cable.websocket_options()}
        )
        |> Plug.Conn.halt()
  end

  test "cable connections that only receive are not closed by the read timeout" do
    {:ok, server} =
      Bandit.start_link(
        plug: QuietUpgrade,
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

    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
    assert response =~ "101 Switching Protocols"
    assert :gen_tcp.recv(socket, 0, 700) == {:error, :timeout}
  end
end
