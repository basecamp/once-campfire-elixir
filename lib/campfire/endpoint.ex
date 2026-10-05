defmodule Campfire.Endpoint do
  @moduledoc "Controller and parameter failures use the pinned public exception responses."
  def init(options), do: Campfire.Router.init(options)

  def call(conn, options) do
    case Campfire.Front.call(conn) do
      %Plug.Conn{halted: true} = conn -> conn
      conn -> Campfire.Router.call(conn, options)
    end
  rescue
    error in Plug.Conn.WrapperError ->
      respond(error.conn, error.reason)

    error ->
      respond(conn, error)
  end

  defp respond(conn, error) do
    if conn.state in [:sent, :chunked] do
      raise error
    else
      Campfire.HttpResponse.error(conn, Plug.Exception.status(error))
    end
  end
end
