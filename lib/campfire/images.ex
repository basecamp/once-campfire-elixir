defmodule Campfire.Images do
  import Plug.Conn
  alias Campfire.{Auth, DB, Filename, Rails, Storage}
  require EEx
  EEx.function_from_file(:defp, :avatar_svg, "priv/templates/avatar.svg.eex", [:assigns])

  @colors ~w(#AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53 #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E)

  def logo(conn) do
    account = DB.one("SELECT * FROM accounts LIMIT 1")

    case Campfire.ModelCache.stale(conn, "accounts", account) do
      {:fresh, conn} -> conn
      {:stale, conn} -> render_logo(conn, account)
    end
  end

  defp render_logo(conn, account) do
    attachment =
      if account,
        do:
          DB.one(
            "SELECT * FROM active_storage_attachments WHERE record_type='Account' AND record_id=? AND name='logo'",
            [account["id"]]
          )

    if attachment &&
         Storage.variable?(
           DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [attachment["blob_id"]])
         ) do
      blob = DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [attachment["blob_id"]])
      size = if conn.params["size"] == "small", do: 192, else: 512
      typed = %{"hash" => [["format", %{"sym" => "png"}], ["resize_to_limit", [size, size]]]}

      case Campfire.StorageMedia.process(blob, typed) do
        {:ok, variant} ->
          conn
          |> put_resp_header("content-type", "image/png")
          |> put_resp_header(
            "content-disposition",
            Filename.disposition("inline", variant["key"])
          )
          |> put_resp_header(
            "cache-control",
            "max-age=300, public, stale-while-revalidate=604800"
          )
          |> send_file(200, Storage.path(variant["key"]))

        {:error, _} ->
          send_resp(conn, 500, "")
      end
    else
      filename = if conn.params["size"] == "small", do: "app-icon-192.png", else: "app-icon.png"

      conn
      |> put_resp_header("content-type", "image/png")
      |> put_resp_header(
        "content-disposition",
        "inline; filename=\"#{filename}\"; filename*=UTF-8''#{filename}"
      )
      |> put_resp_header("cache-control", "max-age=300, public, stale-while-revalidate=604800")
      |> send_file(200, Campfire.Assets.file("images/logos/" <> filename))
    end
  end

  def avatar(conn, token) do
    {conn, current, session} = Auth.session_user(conn)

    if current do
      conn = Auth.set_auth_cookie(conn, session)

      with id when is_integer(id) <- Rails.verify_id("User", token, "avatar"),
           user when is_map(user) <- DB.one("SELECT * FROM users WHERE id=?", [id]) do
        case Campfire.ModelCache.stale(conn, "users", user) do
          {:fresh, conn} -> conn
          {:stale, conn} -> render_avatar(conn, user)
        end
      else
        _ -> conn |> put_resp_header("content-type", "text/html") |> send_resp(404, "")
      end
    else
      Auth.request_authentication(conn)
    end
  end

  defp render_avatar(conn, user) do
    id = user["id"]

    attachment =
      DB.one(
        "SELECT * FROM active_storage_attachments WHERE record_type='User' AND record_id=? AND name='avatar'",
        [id]
      )

    conn =
      put_resp_header(
        conn,
        "cache-control",
        "max-age=1800, public, stale-while-revalidate=604800"
      )

    cond do
      attachment &&
          Storage.variable?(
            DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [attachment["blob_id"]])
          ) ->
        blob =
          DB.one("SELECT * FROM active_storage_blobs WHERE id=?", [attachment["blob_id"]])

        typed = %{"hash" => [["format", %{"sym" => "webp"}], ["resize_to_limit", [512, 512]]]}

        case Campfire.StorageMedia.process(blob, typed) do
          {:ok, variant} ->
            conn
            |> put_resp_header("content-type", "image/webp")
            |> put_resp_header(
              "content-disposition",
              Filename.disposition("inline", variant["key"])
            )
            |> send_file(200, Storage.path(variant["key"]))

          {:error, _} ->
            send_resp(conn, 500, "")
        end

      user["role"] == 2 ->
        conn
        |> put_resp_header("content-type", "image/svg+xml")
        |> put_resp_header(
          "content-disposition",
          "inline; filename=\"default-bot-avatar.svg\"; filename*=UTF-8''default-bot-avatar.svg"
        )
        |> send_file(200, Campfire.Assets.file("images/default-bot-avatar.svg"))

      true ->
        initials = Regex.scan(~r/\b\w/u, user["name"]) |> List.flatten() |> Enum.join()
        color = Enum.at(@colors, rem(:erlang.crc32(to_string(id)), length(@colors)))

        conn
        |> put_resp_header("content-type", "image/svg+xml; charset=utf-8")
        |> send_resp(200, avatar_svg(initials: initials, color: color))
    end
  end
end
