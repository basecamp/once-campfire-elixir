defmodule Campfire.Presence do
  alias Campfire.{Chat, Clock, DB}

  def present(user, room) do
    DB.transaction(fn query ->
      [membership] =
        query.("SELECT * FROM memberships WHERE user_id=? AND room_id=?", [user["id"], room["id"]])

      count = if connected?(membership), do: membership["connections"] + 1, else: 1

      query.("UPDATE memberships SET connections=?,connected_at=?,unread_at=NULL WHERE id=?", [
        count,
        Chat.timestamp(),
        membership["id"]
      ])

      :ok
    end)
  end

  def absent(user, room) do
    change(user, room, fn membership ->
      count = if connected?(membership), do: membership["connections"] - 1, else: 0
      {count, if(count < 1, do: nil, else: membership["connected_at"])}
    end)
  end

  def refresh(user, room) do
    change(user, room, fn membership ->
      count = if connected?(membership), do: membership["connections"], else: 1
      {count, Chat.timestamp()}
    end)
  end

  defp change(user, room, fun) do
    DB.transaction(fn query ->
      case query.("SELECT * FROM memberships WHERE user_id=? AND room_id=?", [
             user["id"],
             room["id"]
           ]) do
        [membership] ->
          {count, connected_at} = fun.(membership)

          updated =
            if NaiveDateTime.compare(
                 NaiveDateTime.from_iso8601!(String.replace(membership["updated_at"], " ", "T")),
                 DateTime.to_naive(Clock.now())
               ) == :eq, do: membership["updated_at"], else: Chat.timestamp()

          query.("UPDATE memberships SET connections=?,connected_at=?,updated_at=? WHERE id=?", [
            count,
            connected_at,
            updated,
            membership["id"]
          ])

        [] ->
          :ok
      end

      :ok
    end)
  end

  defp connected?(%{"connected_at" => nil}), do: false

  defp connected?(membership) do
    at = NaiveDateTime.from_iso8601!(String.replace(membership["connected_at"], " ", "T"))
    NaiveDateTime.compare(at, DateTime.to_naive(DateTime.add(Clock.now(), -60))) != :lt
  end
end
