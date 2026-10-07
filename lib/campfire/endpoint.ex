defmodule Campfire.Endpoint do
  @moduledoc "Controller and parameter failures use the pinned public exception responses."
  def init(options), do: Campfire.Router.init(options)

  def call(conn, options) do
    case Campfire.Front.call(conn) do
      %Plug.Conn{halted: true} = conn -> conn
      conn -> Campfire.Router.call(conn, options)
    end
  rescue
    error in Campfire.Front.BodyTooLarge ->
      too_large(conn, error)

    error in Plug.Conn.WrapperError ->
      if is_struct(error.reason, Campfire.Front.BodyTooLarge),
        do: too_large(error.conn, error.reason),
        else: respond(error.conn, error.reason)

    error ->
      respond(conn, error)
  end

  # A body read past MAX_REQUEST_BODY gets the front's empty 413, as when Content-Length is over.
  defp too_large(conn, error) do
    if conn.state in [:sent, :chunked], do: raise(error), else: Campfire.Front.too_large(conn)
  end

  defp respond(conn, error) do
    if conn.state in [:sent, :chunked] do
      raise error
    else
      Campfire.HttpResponse.error(conn, Plug.Exception.status(error))
    end
  end
end
