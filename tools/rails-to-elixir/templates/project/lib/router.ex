defmodule @@MODULE@@.Router do
  use Plug.Router
  plug :match
  plug :dispatch
  match _, do: send_resp(conn, 501, "Implement against the pinned Rails reference")
end
