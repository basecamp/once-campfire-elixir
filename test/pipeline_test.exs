defmodule Campfire.PipelineTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn, only: [put_req_header: 3, get_resp_header: 2]
  alias Campfire.{HttpCompression, Router}

  setup do
    System.put_env("CAMPFIRE_CLOCK", "2026-03-02T16:00:00Z")
    on_exit(fn -> System.delete_env("CAMPFIRE_CLOCK") end)
  end

  defp get(path, headers \\ []) do
    Enum.reduce(headers, conn(:get, path), fn {k, v}, c -> put_req_header(c, k, v) end)
    |> Router.call(Router.init([]))
  end

  test "Accept-Encoding negotiation is the same on a kept repeat" do
    for {header, expected} <- [
          {"gzip, deflate, br", "gzip"},
          {"br", "identity"},
          {"gzip;q=0, identity;q=0", nil},
          {"*;q=0.5, identity;q=0.4", "gzip"}
        ] do
      assert HttpCompression.encoding(header) == expected
      assert HttpCompression.encoding(header) == expected
    end
  end

  test "a kept gzip body decodes to the body and carries the current mtime" do
    for _ <- 1..2 do
      response = get("/up", [{"accept-encoding", "gzip"}])
      gzip = IO.iodata_to_binary(response.resp_body)
      assert :zlib.gunzip(gzip) =~ "background-color: green"
      <<_::binary-size(4), mtime::little-unsigned-32, _::binary>> = gzip
      assert mtime == DateTime.to_unix(~U[2026-03-02 16:00:00Z])
    end
  end

  test "security headers are added once, in order, without replacing a response's own" do
    response = get("/up")

    names =
      for {name, _} <- response.resp_headers,
          name in ~w(x-frame-options x-xss-protection x-content-type-options x-permitted-cross-domain-policies referrer-policy),
          do: name

    assert names ==
             ~w(x-frame-options x-xss-protection x-content-type-options x-permitted-cross-domain-policies referrer-policy)

    assert get_resp_header(response, "x-frame-options") == ["SAMEORIGIN"]
  end

  test "public files are found through escapes and dot segments, and other paths pass" do
    assert get("/robots.txt").status == 200
    assert get("/%72obots.txt").status == 200
    assert get("/rooms/../robots.txt").status == 200
    assert get("/up").status == 200
  end

  test "the URL context from forwarded headers is the same on a kept repeat" do
    for _ <- 1..2 do
      conn =
        conn(:get, "/up")
        |> Map.put(:remote_ip, {127, 0, 0, 1})
        |> put_req_header("x-forwarded-proto", "https")
        |> put_req_header("x-forwarded-host", "chat.example.com:8443")
        |> Campfire.RequestURL.call([])

      assert {conn.scheme, conn.host, conn.port} == {:https, "chat.example.com", 8443}
    end
  end
end
