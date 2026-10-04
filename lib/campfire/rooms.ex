defmodule Campfire.Rooms do
  alias Campfire.{Chat, DB}
  @types ["Rooms::Open", "Rooms::Closed", "Rooms::Direct"]

  def allowed_to_create?(user) do
    account = DB.one("SELECT settings FROM accounts LIMIT 1")

    settings =
      if account && account["settings"], do: Jason.decode!(account["settings"]), else: %{}

    user["role"] == 1 || !settings["restrict_room_creation_to_administrators"]
  end

  def scoped(user, id, type \\ nil) do
    case Chat.room(user, id) do
      nil ->
        nil

      room ->
        if (type in ["Rooms::Open", "Rooms::Closed"] && room["type"] == "Rooms::Direct") ||
             (type == "Rooms::Direct" && room["type"] != "Rooms::Direct"), do: nil, else: room
    end
  end

  def create(user, type, attrs, user_ids \\ []) when type in @types do
    ids = selected_ids(user_ids)
    ids = if type == "Rooms::Direct", do: Enum.uniq([user["id"] | ids]), else: ids

    ids =
      if type == "Rooms::Open",
        do: Enum.map(DB.query("SELECT id FROM users WHERE status=0"), & &1["id"]),
        else: ids

    existing = if type == "Rooms::Direct", do: find_direct(ids)

    if existing do
      existing
    else
      now = Chat.timestamp()

      DB.transaction(fn query ->
        [room] =
          query.(
            "INSERT INTO rooms (type,name,creator_id,created_at,updated_at) VALUES (?,?,?,?,?) RETURNING *",
            [type, attrs["name"], user["id"], now, now]
          )

        if type == "Rooms::Open", do: grant(query, room, [user["id"]], now)
        grant(query, room, ids, now)
        room
      end)
    end
  end

  def update(room, type, attrs, user_ids \\ []) when type in @types do
    if room["type"] == "Rooms::Direct" && type != "Rooms::Direct" do
      {:error, :direct_room_type}
    else
      now = Chat.timestamp()
      ids = selected_ids(user_ids)

      result =
        DB.transaction(fn query ->
          old_ids =
            Enum.map(
              query.("SELECT user_id FROM memberships WHERE room_id=?", [room["id"]]),
              & &1["user_id"]
            )

          name = Campfire.Params.string(Map.get(attrs, "name", room["name"]))

          updated =
            if type == room["type"] && name == room["name"] do
              room
            else
              [updated] =
                query.("UPDATE rooms SET type=?,name=?,updated_at=? WHERE id=? RETURNING *", [
                  type,
                  name,
                  now,
                  room["id"]
                ])

              updated
            end

          cond do
            type == "Rooms::Open" && room["type"] != type ->
              grant(
                query,
                updated,
                Enum.map(query.("SELECT id FROM users WHERE status=0", []), & &1["id"]),
                now
              )

            type == "Rooms::Closed" ->
              grant(query, updated, ids, now)

              memberships =
                query.("SELECT id,user_id FROM memberships WHERE room_id=?", [room["id"]])

              for m <- memberships,
                  m["user_id"] not in ids,
                  do: query.("DELETE FROM memberships WHERE id=?", [m["id"]])

            true ->
              :ok
          end

          revoked = if type == "Rooms::Closed", do: old_ids -- ids, else: []
          {updated, revoked}
        end)

      case result do
        {updated, revoked} when is_map(updated) and is_list(revoked) ->
          for id <- revoked, do: Campfire.Cable.disconnect(id, true)
          updated

        error ->
          error
      end
    end
  end

  def involvement(user, room, value)
      when value in ["invisible", "nothing", "mentions", "everything"] do
    membership =
      DB.one("SELECT * FROM memberships WHERE room_id=? AND user_id=?", [room["id"], user["id"]])

    if membership["involvement"] == value do
      membership
    else
      updated =
        if NaiveDateTime.compare(
             NaiveDateTime.from_iso8601!(String.replace(membership["updated_at"], " ", "T")),
             DateTime.to_naive(Campfire.Clock.now())
           ) == :eq,
           do: membership["updated_at"],
           else: Chat.timestamp()

      DB.one("UPDATE memberships SET involvement=?,updated_at=? WHERE id=? RETURNING *", [
        value,
        updated,
        membership["id"]
      ])
    end
  end

  def involvement(_, _, _), do: {:error, :invalid_involvement}

  def destroy(room) do
    result =
      DB.transaction(fn query ->
        blobs =
          query.("SELECT * FROM messages WHERE room_id=?", [room["id"]])
          |> Enum.flat_map(&Chat.delete_message_records(query, &1))

        query.("DELETE FROM memberships WHERE room_id=?", [room["id"]])
        query.("DELETE FROM rooms WHERE id=?", [room["id"]])
        {:deleted, blobs}
      end)

    case result do
      {:deleted, blobs} ->
        Enum.each(blobs, &Campfire.Attachments.purge_later/1)
        :ok

      error ->
        error
    end
  end

  defp selected_ids(ids) do
    ids = Enum.map(List.wrap(ids), &Chat.integer/1) |> Enum.uniq()
    Enum.filter(ids, fn id -> DB.one("SELECT id FROM users WHERE id=?", [id]) != nil end)
  end

  defp find_direct(ids) do
    rooms = DB.query("SELECT * FROM rooms WHERE type='Rooms::Direct' ORDER BY id")
    expected = MapSet.new(ids)

    Enum.find(rooms, fn room ->
      MapSet.new(
        Enum.map(
          DB.query("SELECT user_id FROM memberships WHERE room_id=?", [room["id"]]),
          & &1["user_id"]
        )
      ) == expected
    end)
  end

  defp grant(query, room, ids, _now) do
    now = Campfire.People.bulk_timestamp()
    involvement = if room["type"] == "Rooms::Direct", do: "everything", else: "mentions"

    for id <- ids do
      query.(
        "INSERT OR IGNORE INTO memberships (room_id,user_id,involvement,created_at,updated_at) VALUES (?,?,?,?,?)",
        [room["id"], id, involvement, now, now]
      )
    end
  end
end
