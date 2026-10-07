defmodule Campfire.Involvement do
  import Plug.Conn
  alias Campfire.{Auth, Broadcasts, Chat, DB}
  require EEx
  EEx.function_from_file(:defp, :frame, "priv/templates/involvement.html.eex", [:assigns])

  @labels %{
    "mentions" => "Notifying about @ mentions",
    "everything" => "Notifying about all messages",
    "nothing" => "Notifications are off",
    "invisible" => "Notifications are off and room invisible in sidebar"
  }

  def profile_frame(room, current) do
    order =
      if room["type"] == "Rooms::Direct",
        do: ~w(everything nothing),
        else: ~w(mentions everything nothing invisible)

    next = Enum.at(order, Enum.find_index(order, &(&1 == current)) + 1) || List.first(order)
    key = Broadcasts.room_key(room)

    content =
      frame(
        id: room["id"],
        key: key,
        current: current,
        next: next,
        label: @labels[current]
      )

    content = content |> String.replace_prefix("      ", "") |> String.replace_suffix("\n\n", "")

    content
    |> String.replace_prefix("<turbo-frame", "<turbo-frame")
    |> then(fn html ->
      [_, inner] = String.split(html, ">", parts: 2)

      "<turbo-frame id=\"involvement_#{key}\">" <>
        String.replace_prefix(inner, "\n  ", "\n      ")
    end)
  end

  def show(conn, room_id) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user ->
        Auth.request_authentication(conn)

      Auth.banned?(conn) ->
        send_resp(conn, 429, "")

      true ->
        if room = Chat.room(user, room_id) do
          current =
            DB.one("SELECT involvement FROM memberships WHERE user_id=? AND room_id=?", [
              user["id"],
              room["id"]
            ])["involvement"]

          order =
            if room["type"] == "Rooms::Direct",
              do: ~w(everything nothing),
              else: ~w(mentions everything nothing invisible)

          next = Enum.at(order, Enum.find_index(order, &(&1 == current)) + 1) || List.first(order)
          {conn, data} = Auth.csrf_session(conn)

          content =
            frame(
              id: room["id"],
              key: Broadcasts.room_key(room),
              current: current,
              next: next,
              label: @labels[current]
            )

          {conn, html} = Campfire.Page.render(conn, user, data, content: content)

          conn
          |> Auth.set_auth_cookie(session)
          |> put_resp_content_type("text/html")
          |> send_resp(200, html)
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(404, ~s({"status":404,"error":"Not Found"}))
        end
    end
  end
end
