defmodule Campfire.People do
  alias Campfire.{Chat, DB}

  def ban(user) do
    now = Campfire.Chat.timestamp()

    DB.transaction(fn q ->
      ips = q.("SELECT DISTINCT ip_address FROM sessions WHERE user_id=?", [user["id"]])

      for row <- ips, Campfire.Chat.present?(row["ip_address"]) do
        q.("INSERT INTO bans (user_id,ip_address,created_at,updated_at) VALUES (?,?,?,?)", [
          user["id"],
          row["ip_address"],
          now,
          now
        ])
      end

      q.("DELETE FROM sessions WHERE user_id=?", [user["id"]])
      q.("UPDATE users SET status=2,updated_at=? WHERE id=?", [now, user["id"]])
    end)

    Campfire.Cable.disconnect(user["id"], false)

    Campfire.Jobs.enqueue("RemoveBannedContentJob", [
      %{"_aj_globalid" => "gid://campfire/User/#{user["id"]}"}
    ])
  end

  def unban(user) do
    DB.transaction(fn q ->
      q.("DELETE FROM bans WHERE user_id=?", [user["id"]])

      if user["status"] != 0,
        do:
          q.("UPDATE users SET status=0,updated_at=? WHERE id=?", [
            Campfire.Chat.timestamp(),
            user["id"]
          ])
    end)
  end

  def create(attrs, role \\ 0) do
    now = Chat.timestamp()
    digest = password_digest(attrs["password"])
    token = if role == 2, do: alphanumeric(12)
    {:ok, avatar} = Campfire.Attachments.prepare(attrs["avatar"])

    result =
      DB.transaction(fn query ->
        [user] =
          query.(
            "INSERT INTO users (name,email_address,password_digest,role,status,bot_token,created_at,updated_at) VALUES (?,?,?,?,0,?,?,?) RETURNING *",
            [
              Campfire.Params.string(attrs["name"]),
              Campfire.Params.string(attrs["email_address"]),
              digest,
              role,
              token,
              now,
              now
            ]
          )

        if avatar, do: Campfire.Attachments.save(query, avatar, "User", user["id"], "avatar")
        user
      end)

    if match?({:error, _}, result), do: Campfire.Attachments.discard(avatar)

    if is_map(result) do
      DB.query(
        "INSERT OR IGNORE INTO memberships (room_id,user_id,created_at,updated_at) SELECT id,?,?,? FROM rooms WHERE type='Rooms::Open'",
        [result["id"], bulk_timestamp(), bulk_timestamp()]
      )
    end

    if is_map(result) && avatar do
      Campfire.Attachments.find("User", result["id"], "avatar")
      |> Campfire.Attachments.analyze_later()
    end

    if is_map(result) && role == 2 && attrs["webhook_url"] not in [nil, false] do
      [] =
        DB.query("INSERT INTO webhooks (user_id,url,created_at,updated_at) VALUES (?,?,?,?)", [
          result["id"],
          Campfire.Params.string(attrs["webhook_url"]),
          now,
          now
        ])
    end

    result
  end

  def first_run(attrs) do
    # Rails creates the singleton account before the room/user. A repeated setup
    # must not create a second account, even under concurrent requests.
    now = Chat.timestamp()

    account =
      DB.query(
        "INSERT INTO accounts (name,join_code,settings,created_at,updated_at) VALUES ('Campfire',?,'{\"restrict_room_creation_to_administrators\":false}',?,?) RETURNING *",
        [join_code(), now, now]
      )

    case account do
      {:error, _} ->
        {:error, :already_configured}

      [_] ->
        digest = password_digest(attrs["password"])
        {:ok, avatar} = Campfire.Attachments.prepare(attrs["avatar"])

        result =
          DB.transaction(fn query ->
            [user] =
              query.(
                "INSERT INTO users (name,email_address,password_digest,role,status,created_at,updated_at) VALUES (?,?,?,1,0,?,?) RETURNING *",
                [
                  Campfire.Params.string(attrs["name"]),
                  Campfire.Params.string(attrs["email_address"]),
                  digest,
                  now,
                  now
                ]
              )

            if avatar, do: Campfire.Attachments.save(query, avatar, "User", user["id"], "avatar")

            [room] =
              query.(
                "INSERT INTO rooms (name,type,creator_id,created_at,updated_at) VALUES ('All Talk','Rooms::Open',?,?,?) RETURNING *",
                [user["id"], now, now]
              )

            {user, room}
          end)

        case result do
          {user, room} when is_map(user) ->
            # User creation, open-room commit, then explicit creator grant each
            # use insert_all. Conflicting inserts consume SQLite sequence IDs.
            [] =
              DB.query(
                "INSERT OR IGNORE INTO memberships (room_id,user_id,created_at,updated_at) SELECT id,?,?,? FROM rooms WHERE type='Rooms::Open'",
                [user["id"], bulk_timestamp(), bulk_timestamp()]
              )

            [] =
              DB.query(
                "INSERT OR IGNORE INTO memberships (room_id,user_id,involvement,created_at,updated_at) SELECT ?,id,'mentions',?,? FROM users WHERE status=0",
                [room["id"], bulk_timestamp(), bulk_timestamp()]
              )

            [] =
              DB.query(
                "INSERT OR IGNORE INTO memberships (room_id,user_id,involvement,created_at,updated_at) VALUES (?,?,'mentions',?,?)",
                [room["id"], user["id"], bulk_timestamp(), bulk_timestamp()]
              )

            if avatar,
              do:
                Campfire.Attachments.find("User", user["id"], "avatar")
                |> Campfire.Attachments.analyze_later()

            user

          error ->
            Campfire.Attachments.discard(avatar)
            error
        end
    end
  end

  def update(user, attrs) do
    now = Chat.timestamp()
    avatar = Map.get(attrs, "avatar", :unchanged)
    avatar = if is_nil(avatar), do: :unchanged, else: avatar

    values =
      Map.take(attrs, ~w(name email_address bio))
      |> Map.reject(fn {_, value} -> is_nil(value) end)
      |> Map.new(fn {key, value} -> {key, Campfire.Params.string(value)} end)

    digest = password_digest(attrs["password"])
    values = if digest, do: Map.put(values, "password_digest", digest), else: values

    Campfire.Attachments.atomic("User", user["id"], "avatar", avatar, fn q ->
      if Enum.all?(values, fn {key, value} -> user[key] == value end) do
        user
      else
        fields = Map.keys(values)

        [updated] =
          q.(
            "UPDATE users SET " <>
              Enum.map_join(fields, ",", &(&1 <> "=?")) <> ",updated_at=? WHERE id=? RETURNING *",
            Enum.map(fields, &values[&1]) ++ [now, user["id"]]
          )

        updated
      end
    end)
  end

  def update_password(user, password) when is_binary(password) and password != "" do
    DB.one("UPDATE users SET password_digest=?,updated_at=? WHERE id=? RETURNING *", [
      password_digest(password),
      Chat.timestamp(),
      user["id"]
    ])
  end

  def update_password(user, _), do: user

  def deactivate(user) do
    now = Chat.timestamp()

    email =
      if user["email_address"],
        do: String.replace(user["email_address"], "@", "-deactivated-#{Chat.uuid()}@")

    result =
      DB.transaction(fn query ->
        query.(
          "DELETE FROM memberships WHERE user_id=? AND room_id IN (SELECT id FROM rooms WHERE type!='Rooms::Direct')",
          [user["id"]]
        )

        for table <- ["push_subscriptions", "searches", "sessions"],
            do: query.("DELETE FROM #{table} WHERE user_id=?", [user["id"]])

        [updated] =
          query.(
            "UPDATE users SET status=1,email_address=?,updated_at=? WHERE id=? RETURNING *",
            [
              email,
              now,
              user["id"]
            ]
          )

        updated
      end)

    if is_map(result), do: Campfire.Cable.disconnect(user["id"], false)
    result
  end

  def reset_bot_key(bot) do
    DB.one("UPDATE users SET bot_token=?,updated_at=? WHERE id=? AND role=2 RETURNING *", [
      alphanumeric(12),
      Chat.timestamp(),
      bot["id"]
    ])
  end

  def update_bot(bot, attrs) do
    now = Chat.timestamp()

    webhook_url = attrs["webhook_url"]

    Campfire.Attachments.atomic(
      "User",
      bot["id"],
      "avatar",
      Map.get(attrs, "avatar", :unchanged),
      fn query ->
        if Chat.present?(attrs["webhook_url"]) do
          case query.("SELECT id,url FROM webhooks WHERE user_id=?", [bot["id"]]) do
            [] ->
              query.(
                "INSERT INTO webhooks (user_id,url,created_at,updated_at) VALUES (?,?,?,?)",
                [
                  bot["id"],
                  attrs["webhook_url"],
                  now,
                  now
                ]
              )

            [%{"url" => url}] when url == webhook_url ->
              :ok

            [_] ->
              query.("UPDATE webhooks SET url=?,updated_at=? WHERE user_id=?", [
                attrs["webhook_url"],
                now,
                bot["id"]
              ])
          end
        else
          query.("DELETE FROM webhooks WHERE user_id=?", [bot["id"]])
        end

        name = Campfire.Params.string(Map.get(attrs, "name", bot["name"]))

        if name == bot["name"] do
          bot
        else
          [user] =
            query.("UPDATE users SET name=?,updated_at=? WHERE id=? RETURNING *", [
              name,
              now,
              bot["id"]
            ])

          user
        end
      end
    )
  end

  def bulk_timestamp do
    now = Campfire.Clock.now()
    base = Calendar.strftime(now, "%Y-%m-%d %H:%M:%S")
    {micro, _} = now.microsecond
    base <> "." <> String.pad_leading(to_string(div(micro, 1000)), 3, "0")
  end

  def join_code,
    do:
      alphanumeric(12)
      |> String.codepoints()
      |> Enum.chunk_every(4)
      |> Enum.map_join("-", &Enum.join/1)

  defp alphanumeric(length) do
    Campfire.Random.token(
      length,
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    )
  end

  defp password_digest(value) when is_binary(value) and value != "",
    do: Bcrypt.hash_pwd_salt(value, log_rounds: 12)

  defp password_digest(value) when value in [nil, ""], do: nil
  defp password_digest(_), do: raise(ArgumentError, "password must be a string")
end
