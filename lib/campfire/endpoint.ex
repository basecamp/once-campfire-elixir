defmodule Campfire.Endpoint do
  @moduledoc "Controller and parameter failures use the pinned public exception responses."
  def init(options), do: Campfire.Router.init(options)

  def call(conn, options) do
    Campfire.Router.call(conn, options)
  rescue
    error in Plug.Conn.WrapperError ->
      respond(error.conn, error.reason)

    error ->
      respond(conn, error)
  after
    Campfire.ResponseCache.finish()
  end

  defp respond(conn, error) do
    if conn.state in [:sent, :chunked] do
      raise error
    else
      Campfire.HttpResponse.error(conn, Plug.Exception.status(error))
    end
  end
end
