defmodule Campfire.PipelineTest do
  use ExUnit.Case, async: true
  alias Campfire.{HttpCompression, Rails}

  test "cookie escaping matches URI.encode with unreserved characters" do
    for value <- [
          "",
          "abcXYZ019-_.~",
          "a+b/c==--d%e f",
          Base.encode64(:crypto.strong_rand_bytes(300)),
          <<0, 255, 128, 10, 13>>,
          "üñí©ødé"
        ] do
      assert Rails.cookie_escape(value) == URI.encode(value, &URI.char_unreserved?/1)
    end
  end

  test "encoding fast paths agree with negotiation" do
    for raw <- ["", "gzip", "gzip, deflate", "gzip, deflate, br", "gzip, deflate, br, zstd"] do
      assert HttpCompression.encoding(raw) == HttpCompression.encoding(raw <> ";q=1")
    end

    assert HttpCompression.encoding("") == "identity"
    assert HttpCompression.encoding("gzip, deflate, br") == "gzip"
    assert HttpCompression.encoding("br") == "identity"
    assert HttpCompression.encoding("identity") == "identity"
  end

  test "forwarded authority parsing keeps host and numeric port" do
    for {authority, expected} <- [
          {"chat.example.com:8443", {"chat.example.com", 8443}},
          {"[::1]:80", {"[::1]", 80}},
          {"chat.example.com", {"chat.example.com", 80}},
          {"chat.example.com:", {"chat.example.com:", 80}},
          {"chat.example.com:abc", {"chat.example.com:abc", 80}}
        ] do
      conn =
        Plug.Test.conn(:get, "/")
        |> Map.put(:remote_ip, {127, 0, 0, 1})
        |> Plug.Conn.put_req_header("x-forwarded-host", authority)
        |> Campfire.RequestURL.call([])

      assert {conn.host, conn.port} == expected, authority
    end
  end
end
