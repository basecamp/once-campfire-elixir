defmodule Campfire.FrontTLSTest do
  use ExUnit.Case, async: false
  @moduletag :capture_log
  alias Campfire.Front.{Config, Server}

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  setup do
    storage = Path.join(System.tmp_dir!(), "campfire-tls-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(storage) end)
    {http, https} = {free_port(), free_port()}

    config =
      Config.load(%{
        "TLS_DOMAIN" => "campfire.test",
        "HTTP_PORT" => to_string(http),
        "HTTPS_PORT" => to_string(https),
        "THRUSTER_STORAGE_PATH" => storage,
        "LOG_REQUESTS" => "false"
      })

    on_exit(fn -> Config.load() end)
    for child <- Server.children(config), do: start_supervised!(child)
    %{http: http, https: https}
  end

  test "HTTPS negotiates HTTP/2 with a certificate for the domain", %{https: https} do
    {:ok, socket} =
      :ssl.connect(~c"127.0.0.1", https,
        verify: :verify_none,
        server_name_indication: ~c"campfire.test",
        alpn_advertised_protocols: ["h2", "http/1.1"]
      )

    assert {:ok, "h2"} = :ssl.negotiated_protocol(socket)
    {:ok, der} = :ssl.peercert(socket)
    assert inspect(:public_key.pkix_decode_cert(der, :otp)) =~ "campfire.test"
    :ssl.close(socket)
  end

  test "HTTP redirects configured hosts to HTTPS and refuses others", %{http: http} do
    request = fn host ->
      {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", http, [:binary, active: false])
      :ok = :gen_tcp.send(socket, "GET /rooms/1?x=2 HTTP/1.1\r\nHost: #{host}\r\n\r\n")
      {:ok, response} = :gen_tcp.recv(socket, 0, 5000)
      :gen_tcp.close(socket)
      response
    end

    response = request.("campfire.test")
    assert response =~ "HTTP/1.1 301"
    assert response =~ "location: https://campfire.test/rooms/1?x=2"
    assert request.("other.test") =~ "HTTP/1.1 421"
  end
end
