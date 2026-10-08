defmodule Campfire.UnfurlLinks do
  import Plug.Conn
  alias Campfire.{Auth, Opengraph, Rails}

  def create(conn) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      !Auth.request_allowed?(conn) ->
        Campfire.HttpResponse.error(conn, 422)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      !is_binary(conn.params["url"]) || String.trim(conn.params["url"]) == "" ->
        Campfire.HttpResponse.error(conn, 400)

      true ->
        conn = Auth.set_auth_cookie(conn, session)

        case Opengraph.from_url(conn.params["url"]) do
          {:ok, attributes} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Rails.json(attributes))

          :invalid ->
            send_resp(conn, 204, "")
        end
    end
  end
end
