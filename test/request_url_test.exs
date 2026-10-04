defmodule Campfire.RequestURLTest do
  use ExUnit.Case, async: true

  test "remote clients cannot rewrite URL context with proxy headers" do
    for peer <- [{203, 0, 113, 1}, {10, 0, 0, 1}, {192, 168, 0, 1}] do
      conn =
        Plug.Test.conn(:get, "http://campfire.test/")
        |> Plug.Conn.put_req_header("x-forwarded-host", "attacker.test")
        |> Plug.Conn.put_req_header("x-forwarded-proto", "https")

      conn = Campfire.RequestURL.call(%{conn | remote_ip: peer}, [])
      assert Campfire.Auth.base(conn) == "http://campfire.test"
    end
  end
end
