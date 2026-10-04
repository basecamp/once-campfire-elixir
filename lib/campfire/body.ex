defmodule Campfire.Body do
  import Plug.Conn

  def read(conn, opts) do
    {status, body, conn} = read_body(conn, opts)
    cached = conn.private[:campfire_raw_body] || []
    {status, body, put_private(conn, :campfire_raw_body, cached ++ [body])}
  end

  def read_all(conn) do
    case conn.private[:campfire_raw_body] do
      nil -> accumulate(conn, [])
      cached -> {:ok, IO.iodata_to_binary(cached), conn}
    end
  end

  defp accumulate(conn, parts) do
    case read_body(conn) do
      {:ok, body, conn} -> {:ok, IO.iodata_to_binary([parts, body]), conn}
      {:more, body, conn} -> accumulate(conn, [parts, body])
      error -> error
    end
  end
end
