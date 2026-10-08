defmodule Campfire.Admin do
  import Plug.Conn
  alias Campfire.{Auth, DB, People, Rooms}

  def call(conn, action, id \\ nil) do
    {conn, user, session} = Auth.session_user(conn)

    cond do
      !user -> Auth.request_authentication(conn)
      !Auth.request_allowed?(conn) -> Campfire.HttpResponse.error(conn, 422)
      Auth.banned?(conn) -> head(conn, 429)
      admin_action?(action) && user["role"] != 1 -> head(conn, 403)
      true -> dispatch(Auth.set_auth_cookie(conn, session), user, action, id)
    end
  end

  defp admin_action?(action),
    do:
      action in [
        :ban,
        :unban,
        :account,
        :destroy_logo,
        :role,
        :deactivate,
        :create_bot,
        :update_bot,
        :delete_bot,
        :reset_bot_key,
        :join_code,
        :custom_styles
      ]

  defp dispatch(conn, _user, action, id) when action in [:ban, :unban] do
    if target = DB.one("SELECT * FROM users WHERE id=?", [Campfire.Chat.integer(id)]) do
      apply(People, action, [target])
      Auth.redirect(conn, "/users/#{target["id"]}")
    else
      head(conn, 404)
    end
  end

  defp dispatch(conn, _user, :account, _) do
    attrs =
      Campfire.Params.required(conn.params, "account")
      |> Campfire.Params.permit(~w(name logo), ["settings"])

    account = DB.one("SELECT * FROM accounts LIMIT 1")

    settings =
      if attrs["settings"] do
        values =
          Jason.decode!(account["settings"] || "{}")
          |> Map.put_new("restrict_room_creation_to_administrators", false)

        values =
          Enum.reduce(attrs["settings"], values, fn
            {"restrict_room_creation_to_administrators" = key, value}, values ->
              Map.put(values, key, boolean(value))

            {key, _}, _ ->
              raise ArgumentError, "unknown account setting: #{key}"
          end)

        Jason.encode!(values)
      else
        account["settings"] || ~s({"restrict_room_creation_to_administrators":false})
      end

    name = Campfire.Params.string(Map.get(attrs, "name", account["name"]))

    result =
      Campfire.Attachments.atomic(
        "Account",
        account["id"],
        "logo",
        Map.get(attrs, "logo", :unchanged),
        fn q ->
          if name != account["name"] || settings != account["settings"] do
            q.("UPDATE accounts SET name=?,settings=?,updated_at=? WHERE id=?", [
              name,
              settings,
              Campfire.Chat.timestamp(),
              account["id"]
            ])
          end

          account
        end
      )

    case result do
      {:error, error} -> raise error
      _ -> :ok
    end

    conn |> Campfire.Flash.put(:notice, "✓") |> Auth.redirect("/account/edit")
  end

  defp dispatch(conn, _user, :destroy_logo, _) do
    account = DB.one("SELECT * FROM accounts LIMIT 1")
    Campfire.Attachments.replace("Account", account["id"], "logo", nil)
    Auth.redirect(conn, "/account/edit")
  end

  defp dispatch(conn, user, :destroy_avatar, _) do
    Campfire.Attachments.replace("User", user["id"], "avatar", nil)
    Auth.redirect(conn, "/users/me/profile")
  end

  defp dispatch(conn, _user, :join_code, _) do
    DB.query("UPDATE accounts SET join_code=?,updated_at=?", [
      People.join_code(),
      Campfire.Chat.timestamp()
    ])

    Auth.redirect(conn, "/account/edit")
  end

  defp dispatch(conn, _user, :custom_styles, _) do
    attrs =
      Campfire.Params.required(conn.params, "account")
      |> Campfire.Params.permit(["custom_styles"])

    account = DB.one("SELECT * FROM accounts LIMIT 1")

    if Map.has_key?(attrs, "custom_styles") do
      styles = Campfire.Params.string(attrs["custom_styles"])

      if styles != account["custom_styles"] do
        case DB.query("UPDATE accounts SET custom_styles=?,updated_at=?", [
               styles,
               Campfire.Chat.timestamp()
             ]) do
          {:error, error} -> raise error
          _ -> :ok
        end
      end
    end

    conn |> Campfire.Flash.put(:notice, "✓") |> Auth.redirect("/account/custom_styles/edit")
  end

  defp dispatch(conn, user, :profile, _) do
    raw = Campfire.Params.required(conn.params, "user")
    attrs = Campfire.Params.permit(raw, ~w(name avatar email_address password bio))
    result = People.update(user, attrs)

    case result do
      {:error, error} -> raise error
      _ -> :ok
    end

    notice =
      if raw["avatar"], do: "It may take up to 30 minutes to change everywhere.", else: "✓"

    conn |> Campfire.Flash.put(:notice, notice) |> Auth.redirect("/users/me/profile")
  end

  defp dispatch(conn, _user, :role, id) do
    target = DB.one("SELECT * FROM users WHERE status=0 AND id=?", [Campfire.Chat.integer(id)])

    if target do
      role =
        if Campfire.Params.required(conn.params, "user")["role"] == "administrator",
          do: 1,
          else: 0

      if role != target["role"] do
        DB.query("UPDATE users SET role=?,updated_at=? WHERE id=?", [
          role,
          Campfire.Chat.timestamp(),
          target["id"]
        ])
      end

      Auth.redirect(conn, "/account/edit")
    else
      head(conn, 404)
    end
  end

  defp dispatch(conn, _user, action, id)
       when action in [:deactivate, :delete_bot, :update_bot, :reset_bot_key] do
    target = DB.one("SELECT * FROM users WHERE status=0 AND id=?", [Campfire.Chat.integer(id)])

    if target && (action == :deactivate || target["role"] == 2) do
      case action do
        :deactivate ->
          People.deactivate(target)

        :delete_bot ->
          People.deactivate(target)

        :update_bot ->
          attrs =
            Campfire.Params.required(conn.params, "user")
            |> Campfire.Params.permit(~w(name avatar webhook_url))

          case People.update_bot(target, attrs) do
            {:error, error} -> raise error
            _ -> :ok
          end

        :reset_bot_key ->
          People.reset_bot_key(target)
      end

      Auth.redirect(conn, if(action == :deactivate, do: "/account/edit", else: "/account/bots"))
    else
      head(conn, 404)
    end
  end

  defp dispatch(conn, _user, :create_bot, _) do
    case People.create(
           Campfire.Params.required(conn.params, "user")
           |> Campfire.Params.permit(~w(name avatar webhook_url)),
           2
         ) do
      bot when is_map(bot) -> Auth.redirect(conn, "/account/bots")
      {:error, error} -> raise error
    end
  end

  defp dispatch(conn, user, {:create_room, type}, _) do
    if type == "Rooms::Direct" || Rooms.allowed_to_create?(user) do
      case Rooms.create(
             user,
             type,
             if(type == "Rooms::Direct",
               do: %{},
               else:
                 Campfire.Params.required(conn.params, "room") |> Campfire.Params.permit(["name"])
             ),
             conn.params["user_ids"] || []
           ) do
        room when is_map(room) ->
          Campfire.Broadcasts.room_create(room)
          Auth.redirect(conn, "/rooms/#{room["id"]}")

        _ ->
          head(conn, 422)
      end
    else
      head(conn, 403)
    end
  end

  defp dispatch(conn, user, {:update_room, type}, id) do
    room = Rooms.scoped(user, id, type)

    cond do
      !room ->
        conn
        |> Campfire.Flash.put("alert", "Room not found or inaccessible")
        |> Auth.redirect("/")

      user["role"] != 1 && room["creator_id"] != user["id"] ->
        head(conn, 403)

      true ->
        case Rooms.update(
               room,
               type,
               if(type == "Rooms::Direct",
                 do: %{},
                 else:
                   Campfire.Params.required(conn.params, "room")
                   |> Campfire.Params.permit(["name"])
               ),
               conn.params["user_ids"] || []
             ) do
          updated when is_map(updated) ->
            Campfire.Broadcasts.room_update(updated)
            Auth.redirect(conn, "/rooms/#{room["id"]}")

          _ ->
            head(conn, 422)
        end
    end
  end

  # These subclasses replace the inherited set_room callback, excluding destroy.
  # Preserve the pinned source's resulting authorization/exception response.
  defp dispatch(conn, user, {:delete_room, type}, _id)
       when type in ["Rooms::Open", "Rooms::Closed"] do
    if user["role"] == 1, do: Campfire.HttpResponse.error(conn, 500), else: head(conn, 403)
  end

  defp dispatch(conn, user, {:delete_room, type}, id) do
    room = Rooms.scoped(user, id, type)

    cond do
      !room ->
        conn
        |> Campfire.Flash.put("alert", "Room not found or inaccessible")
        |> Auth.redirect("/")

      room["type"] != "Rooms::Direct" && user["role"] != 1 && room["creator_id"] != user["id"] ->
        head(conn, 403)

      true ->
        Rooms.destroy(room)
        Campfire.Broadcasts.room_remove(room)
        Auth.redirect(conn, "/")
    end
  end

  defp dispatch(conn, user, :involvement, id) do
    if room = Rooms.scoped(user, id) do
      before =
        DB.one("SELECT involvement FROM memberships WHERE user_id=? AND room_id=?", [
          user["id"],
          room["id"]
        ])["involvement"]

      case Rooms.involvement(user, room, conn.params["involvement"]) do
        {:error, _} ->
          head(conn, 422)

        updated ->
          Campfire.Broadcasts.involvement(user, room, before, updated["involvement"])
          Auth.redirect(conn, "/rooms/#{room["id"]}/involvement")
      end
    else
      Auth.redirect(conn, "/")
    end
  end

  defp head(conn, status),
    do: conn |> put_resp_header("content-type", "text/html") |> send_resp(status, "")

  defp boolean(value) when value in [nil, ""], do: nil

  defp boolean(value) when value in [false, 0, "0", "f", "F", "false", "FALSE", "off", "OFF"],
    do: false

  defp boolean(_), do: true
end
