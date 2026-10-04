defmodule Campfire.Webhooks do
  alias Campfire.{Attachments, Chat, DB, Jobs, Mentions, Network, Storage}
  @external_resource "priv/compat/rails-mime.json"
  @mime Jason.decode!(File.read!(@external_resource))

  def enqueue(room, message) do
    bots =
      DB.query(
        "SELECT u.* FROM users u JOIN memberships m ON m.user_id=u.id JOIN webhooks w ON w.user_id=u.id WHERE m.room_id=? AND u.role=2 AND u.status=0 AND u.id!=?",
        [room["id"], message["creator_id"]]
      )

    text =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    mentioned = if text, do: Enum.map(Mentions.users(text["body"] || ""), & &1["id"]), else: []

    for bot <- bots, room["type"] == "Rooms::Direct" || bot["id"] in mentioned do
      Jobs.enqueue("Bot::WebhookJob", [
        %{"_aj_globalid" => "gid://campfire/User/#{bot["id"]}"},
        %{"_aj_globalid" => "gid://campfire/Message/#{message["id"]}"}
      ])
    end

    :ok
  end

  def payload(bot, room, message) do
    creator = DB.one("SELECT * FROM users WHERE id=?", [message["creator_id"]])

    rich =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    html = if rich, do: rich["body"] || "", else: ""
    plain = Chat.plain_text(html) |> String.replace("@" <> bot["name"], "") |> String.trim()

    %{
      "user" => Map.take(creator, ["id", "name"]),
      "room" => %{
        "id" => room["id"],
        "name" => room["name"],
        "path" => "/rooms/#{room["id"]}/#{bot["id"]}-#{bot["bot_token"]}/messages"
      },
      "message" => %{
        "id" => message["id"],
        "body" => %{"html" => html, "plain" => plain},
        "path" => "/rooms/#{room["id"]}/@#{message["id"]}"
      }
    }
  end

  def encoded_payload(bot, room, message) do
    data = payload(bot, room, message)
    user = Storage.ordered_json(Enum.map(["id", "name"], &{&1, data["user"][&1]}))
    room = Storage.ordered_json(Enum.map(["id", "name", "path"], &{&1, data["room"][&1]}))
    body = Storage.ordered_json(Enum.map(["html", "plain"], &{&1, data["message"]["body"][&1]}))

    message =
      Storage.ordered_json([
        {"id", data["message"]["id"]},
        {"body", {:raw, body}},
        {"path", data["message"]["path"]}
      ])

    Storage.ordered_json([
      {"user", {:raw, user}},
      {"room", {:raw, room}},
      {"message", {:raw, message}}
    ])
  end

  def perform(bot, message) do
    room = DB.one("SELECT * FROM rooms WHERE id=?", [message["room_id"]])
    webhook = DB.one("SELECT * FROM webhooks WHERE user_id=?", [bot["id"]])

    if webhook do
      json = encoded_payload(bot, room, message)

      case Network.request(webhook["url"], :post, [{"Content-Type", "application/json"}], json,
             guard: :none,
             timeout: 7000
           ) do
        {:ok, status, headers, body} ->
          type =
            headers["content-type"] &&
              headers["content-type"]
              |> String.split(";", parts: 2)
              |> hd()
              |> String.trim()
              |> String.downcase()

          cond do
            status == 200 && type in ["text/plain", "text/html"] ->
              text_reply(bot, room, body)

            type ->
              mime = @mime[type] || %{"type" => type, "symbol" => nil}

              {:ok, prepared} =
                Attachments.prepare_bytes(body, "attachment.#{mime["symbol"]}", mime["type"])

              blob = Attachments.persist(prepared)

              message =
                Chat.create_message(bot, room, nil, %{"attachment" => Storage.signed_id(blob)})

              if is_map(message) do
                Attachments.process_message(message)
                Campfire.Broadcasts.create(room, message)
              end

              message

            true ->
              :ok
          end

        {:error, :timeout} ->
          text_reply(bot, room, "Failed to respond within 7 seconds")

        error ->
          error
      end
    else
      :ok
    end
  end

  defp text_reply(bot, room, body) do
    message = Chat.create_message(bot, room, body)
    if is_map(message), do: Campfire.Broadcasts.create(room, message)
    message
  end
end
