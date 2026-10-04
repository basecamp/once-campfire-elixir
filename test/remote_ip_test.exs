defmodule Campfire.RemoteIPTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  @vectors Jason.decode!(File.read!("vectors/remote-ip.json"))
  for {item, index} <- Enum.with_index(@vectors) do
    @item item
    test "pinned ActionDispatch remote IP #{index}" do
      conn = Plug.Test.conn(:get, "/")
      headers = @item["headers"]
      remote = headers["REMOTE_ADDR"] || "127.0.0.1"
      {:ok, address} = :inet.parse_address(String.to_charlist(remote))
      conn = %{conn | remote_ip: address}

      conn =
        Enum.reduce(headers, conn, fn {key, value}, conn ->
          if String.starts_with?(key, "HTTP_"),
            do:
              put_req_header(
                conn,
                key
                |> String.replace_prefix("HTTP_", "")
                |> String.downcase()
                |> String.replace("_", "-"),
                value
              ),
            else: conn
        end)

      if @item["error"],
        do: assert_raise(ArgumentError, fn -> Campfire.RemoteIP.address(conn) end),
        else: assert(Campfire.RemoteIP.address(conn) == @item["address"])
    end
  end
end
