defmodule Campfire.Push do
  alias Campfire.{Chat, DB, Mentions, Network, WebPush}

  @hosts ~w(jmt17.google.com fcm.googleapis.com updates.push.services.mozilla.com web.push.apple.com notify.windows.com)
  def valid_endpoint?(endpoint) when is_binary(endpoint) do
    with {:ok, uri} <- Campfire.HttpURL.parse(endpoint) do
      permitted_uri?(uri) && match?({:ok, _}, Network.resolve(uri.host))
    else
      _ -> false
    end
  end

  def valid_endpoint?(_), do: false

  # The endpoint's scheme, port and push service host, without resolving it.
  defp permitted_endpoint?(endpoint) when is_binary(endpoint) do
    case Campfire.HttpURL.parse(endpoint) do
      {:ok, uri} -> permitted_uri?(uri)
      _ -> false
    end
  end

  defp permitted_endpoint?(_), do: false

  defp permitted_uri?(uri) do
    uri.scheme == "https" && uri.port == 443 && is_binary(uri.host) &&
      Enum.any?(@hosts, fn host ->
        String.downcase(uri.host) == host ||
          String.ends_with?(String.downcase(uri.host), "." <> host)
      end)
  end

  def subscriptions(room, message) do
    cutoff = Chat.timestamp(DateTime.add(Campfire.Clock.now(), -60))

    # Each subscription comes with its membership's involvement, instead of one query each.
    rows =
      DB.query(
        ~s{SELECT s.*, m.involvement AS "push.involvement" FROM push_subscriptions s JOIN memberships m ON m.user_id=s.user_id WHERE m.room_id=? AND m.user_id!=? AND m.involvement IN ('everything','mentions') AND (m.connected_at IS NULL OR m.connected_at < ?)},
        [room["id"], message["creator_id"], cutoff]
      )

    mentioned =
      if rows == [],
        do: [],
        else:
          (case DB.cached_one(
                  "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
                  [message["id"]],
                  ~w(action_text_rich_texts)
                ) do
             nil -> []
             text -> Enum.map(Mentions.users(text["body"] || ""), & &1["id"])
           end)

    for s <- rows,
        s["push.involvement"] == "everything" || s["user_id"] in mentioned,
        do: Map.delete(s, "push.involvement")
  end

  # Only subscriptions to a push service's endpoint need a payload and a badge count; any other
  # endpoint is skipped as deliver/4 would. deliver/4 still resolves the host, as before.
  def perform(room, message) do
    deliverable = Enum.filter(subscriptions(room, message), &permitted_endpoint?(&1["endpoint"]))

    if deliverable != [] do
      creator =
        DB.cached_one("SELECT * FROM users WHERE id=?", [message["creator_id"]], ~w(users))

      body = Chat.present_message(message, "")["body"]["plain_text"]

      payload =
        if room["type"] == "Rooms::Direct",
          do: %{"title" => creator["name"], "body" => body, "path" => "/rooms/#{room["id"]}"},
          else: %{
            "title" => room["name"],
            "body" => "#{creator["name"]}: #{body}",
            "path" => "/rooms/#{room["id"]}"
          }

      deliverable
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
    end

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
