defmodule Campfire.Push do
  alias Campfire.{Chat, DB, Mentions, Network, WebPush}

  @hosts ~w(jmt17.google.com fcm.googleapis.com updates.push.services.mozilla.com web.push.apple.com notify.windows.com)
  def valid_endpoint?(endpoint) when is_binary(endpoint) do
    case Campfire.HttpURL.parse(endpoint) do
      {:ok, uri} ->
        permitted =
          uri.scheme == "https" && uri.port == 443 && is_binary(uri.host) &&
            Enum.any?(@hosts, fn host ->
              String.downcase(uri.host) == host ||
                String.ends_with?(String.downcase(uri.host), "." <> host)
            end)

        permitted && match?({:ok, _}, Network.resolve(uri.host))

      _ ->
        false
    end
  end

  def valid_endpoint?(_), do: false

  def subscriptions(room, message) do
    cutoff = Chat.timestamp(DateTime.add(Campfire.Clock.now(), -60))

    rows =
      DB.query(
        "SELECT s.* FROM push_subscriptions s JOIN memberships m ON m.user_id=s.user_id WHERE m.room_id=? AND m.user_id!=? AND m.involvement IN ('everything','mentions') AND (m.connected_at IS NULL OR m.connected_at < ?)",
        [room["id"], message["creator_id"], cutoff]
      )

    text =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    mentioned = if text, do: Enum.map(Mentions.users(text["body"] || ""), & &1["id"]), else: []

    Enum.filter(rows, fn s ->
      membership =
        DB.one("SELECT involvement FROM memberships WHERE room_id=? AND user_id=?", [
          room["id"],
          s["user_id"]
        ])

      membership["involvement"] == "everything" || s["user_id"] in mentioned
    end)
  end

  def perform(room, message) do
    creator = DB.one("SELECT * FROM users WHERE id=?", [message["creator_id"]])
    body = Chat.present_message(message, "")["body"]["plain_text"]

    payload =
      if room["type"] == "Rooms::Direct",
        do: %{"title" => creator["name"], "body" => body, "path" => "/rooms/#{room["id"]}"},
        else: %{
          "title" => room["name"],
          "body" => "#{creator["name"]}: #{body}",
          "path" => "/rooms/#{room["id"]}"
        }

    subscriptions(room, message)
    |> Task.async_stream(
      fn subscription ->
        badge =
          DB.one(
            "SELECT count(*) AS count FROM memberships WHERE user_id=? AND unread_at IS NOT NULL",
            [subscription["user_id"]]
          )["count"]

        deliver(subscription, payload, badge)
      end,
      max_concurrency: 50,
      timeout: :infinity
    )
    |> Stream.run()

    :ok
  end

  def deliver(subscription, payload, badge, options \\ []) do
    endpoint = subscription["endpoint"]

    if valid_endpoint?(endpoint) do
      uri = URI.parse(endpoint)

      body =
        WebPush.encrypt(
          WebPush.encoded_message(payload, badge),
          subscription["p256dh_key"],
          subscription["auth_key"]
        )

      authorization = WebPush.authorization("https://" <> uri.host)

      case Network.request(
             endpoint,
             :post,
             [
               {"TTL", "2419200"},
               {"Urgency", "high"},
               {"Content-Encoding", "aes128gcm"},
               {"Content-Type", "application/octet-stream"},
               {"Authorization", authorization}
             ],
             body
           ) do
        {:ok, status, _, _} when status == 410 ->
          if Keyword.get(options, :invalidate, true),
            do: DB.query("DELETE FROM push_subscriptions WHERE id=?", [subscription["id"]])

          :expired

        {:error, {:tls_alert, _}} = error ->
          if Keyword.get(options, :invalidate, true),
            do: DB.query("DELETE FROM push_subscriptions WHERE id=?", [subscription["id"]])

          error

        {:ok, status, _, _} when status in 200..299 ->
          :ok

        {:ok, status, _, _} ->
          {:error, {:push_response, status}}

        error ->
          error
      end
    else
      :skipped
    end
  end
end
