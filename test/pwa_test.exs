defmodule Campfire.PwaTest do
  use ExUnit.Case, async: true
  alias Campfire.Pwa
  @vectors Jason.decode!(File.read!("vectors/pwa-views.json"))
  for {name, row} <- @vectors do
    @row row
    test "captured PWA rendering #{name}" do
      conn =
        Plug.Test.conn(:get, "http://campfire.test/rooms/486777696")
        |> Plug.Conn.put_req_header("user-agent", @row["user_agent"])

      if @row["error"] do
        for scope <- [:room, :profile],
            do: assert_raise(Pwa.MissingAsset, fn -> Pwa.render(conn, scope) end)
      else
        for scope <- [:room, :profile],
            do: assert(Pwa.render(conn, scope) == @row[Atom.to_string(scope)])
      end
    end
  end
end
