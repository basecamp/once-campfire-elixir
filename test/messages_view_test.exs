defmodule Campfire.MessagesViewTest do
  use ExUnit.Case, async: false
  alias Campfire.{DB, FragmentCache, MessagesView}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    :ok = DB.restore_fixture(@fixture)
    :ok = FragmentCache.clear()
    message = DB.one("SELECT * FROM messages ORDER BY id LIMIT 1")
    %{message: message}
  end

  test "cached fragments receive the current session's CSRF token", %{message: message} do
    first = MessagesView.render(message, "https://campfire.test", "first-session-token")
    second = MessagesView.render(message, "https://campfire.test", "second-session-token")

    assert first =~ ~s(value="first-session-token")
    refute first =~ "second-session-token"
    assert second =~ ~s(value="second-session-token")
    refute second =~ "first-session-token"
  end

  test "batch rendering preserves current escaped tokens and tokenless broadcasts" do
    messages = DB.query("SELECT * FROM messages ORDER BY id DESC LIMIT 2")
    assert length(messages) == 2
    base = "https://campfire.test"

    for {token, escaped} <- [
          {"first-\"&<>'", "first-&quot;&amp;&lt;&gt;&#39;"},
          {"second-'>&\"<", "second-&#39;&gt;&amp;&quot;&lt;"}
        ] do
      html = MessagesView.render_many(messages, base, token)
      assert html == Enum.map_join(messages, &MessagesView.render(&1, base, token))

      values = Regex.scan(~r/name="authenticity_token" value="([^"]*)"/, html, capture: [1])
      assert Enum.uniq(values) == [[escaped]]
      refute html =~ "campfire-csrf-input"

      broadcast = MessagesView.render_many(messages, base, nil)
      assert broadcast == Enum.map_join(messages, &MessagesView.render(&1, base))
      refute broadcast =~ ~s(name="authenticity_token")
      refute broadcast =~ "campfire-csrf-input"
    end

    assert MessagesView.render_many([], base, "unused-token") == ""
  end

  test "batch rendering preserves tokenless cached items and isolates a failed item" do
    [first, second] = DB.query("SELECT * FROM messages ORDER BY id LIMIT 2")
    base = "https://campfire.test"
    token = "batch-session-token"
    broadcast = MessagesView.render(first, base)
    failed = MessagesView.render(%{second | "creator_id" => -1}, base, token)
    assert failed =~ "Failed to load message content"

    html =
      MessagesView.render_many([first, %{second | "creator_id" => -1}, second], base, token)

    assert html == broadcast <> failed <> MessagesView.render(second, base, token)
    assert html =~ ~s(value="batch-session-token")
    refute html =~ "campfire-csrf-input"
  end

  test "broadcast-cached messages preserve Rails' tokenless fragment behavior", %{
    message: message
  } do
    broadcast = MessagesView.render(message, "https://campfire.test")
    page = MessagesView.render(message, "https://campfire.test", "page-token")

    assert broadcast == page
    refute page =~ "page-token"
    refute page =~ ~s(name="authenticity_token")
  end

  test "page-cached boosts receive the current session's CSRF token" do
    boost = DB.one("SELECT * FROM boosts ORDER BY id LIMIT 1")
    first = MessagesView.render_boost(boost, "first-boost-token")
    second = MessagesView.render_boost(boost, "second-boost-token")

    assert first =~ ~s(value="first-boost-token")
    refute first =~ "second-boost-token"
    assert second =~ ~s(value="second-boost-token")
    refute second =~ "first-boost-token"
  end

  test "broadcast-cached boosts preserve Rails' tokenless fragment behavior" do
    boost = DB.one("SELECT * FROM boosts ORDER BY id LIMIT 1")
    broadcast = MessagesView.render_boost(boost)
    page = MessagesView.render_boost(boost, "page-token")

    assert broadcast == page
    refute page =~ "page-token"
    refute page =~ ~s(name="authenticity_token")
  end

  test "stored rich text cannot inject the internal CSRF placeholder" do
    html = MessagesView.presentation(~s(<p>before<!--campfire-csrf-input-->after</p>))

    assert html =~ "beforeafter"
    refute html =~ "campfire-csrf-input"
  end

  test "broadcast fragments omit CSRF inputs", %{message: message} do
    html = MessagesView.render(message, "https://campfire.test")

    refute html =~ "campfire-csrf-input"
    refute html =~ ~s(name="authenticity_token")
  end

  test "a missing rich-text body renders the full empty message card", %{message: message} do
    DB.query(
      "DELETE FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
      [message["id"]]
    )

    html = MessagesView.render(message, "https://campfire.test")

    assert html =~ message["client_message_id"]
    assert html =~ ~s(data-messages-target="message")
    refute html =~ "Failed to load message content"
  end

  test "missing and explicitly empty rich text remain distinct" do
    assert MessagesView.presentation(nil) == ""
    assert MessagesView.presentation("") =~ ~s(<div class="lexxy-content">)
  end

  test "a failed render does not poison the fragment cache", %{message: message} do
    failed = MessagesView.render(%{message | "creator_id" => -1}, "https://campfire.test")
    assert failed =~ "Failed to load message content"

    recovered = MessagesView.render(message, "https://campfire.test")
    refute recovered =~ "Failed to load message content"
    assert recovered =~ message["client_message_id"]
  end

  test "a failed rich-text presentation does not poison the fragment cache", %{
    message: message
  } do
    %{"body" => body} =
      DB.one(
        "SELECT body FROM action_text_rich_texts WHERE record_type='Message' AND record_id=? AND name='body'",
        [message["id"]]
      )

    DB.query(
      "UPDATE action_text_rich_texts SET body=? WHERE record_type='Message' AND record_id=? AND name='body'",
      [
        "<p>Before <action-text-attachment sgid=\"nope\"></action-text-attachment> after</p>",
        message["id"]
      ]
    )

    failed = MessagesView.render(message, "https://campfire.test")
    assert failed =~ "Failed to load message content"

    DB.query(
      "UPDATE action_text_rich_texts SET body=? WHERE record_type='Message' AND record_id=? AND name='body'",
      [body, message["id"]]
    )

    recovered = MessagesView.render(message, "https://campfire.test")
    refute recovered =~ "Failed to load message content"
    assert recovered =~ message["client_message_id"]
  end

  test "concurrent cache rollover remains bounded and returns every rendered value" do
    for i <- 1..4096, do: FragmentCache.fetch({:seed, i}, fn -> Integer.to_string(i) end)

    results =
      1..100
      |> Task.async_stream(
        fn i -> FragmentCache.fetch({:rollover, i}, fn -> "rollover-#{i}" end) end,
        max_concurrency: 100
      )
      |> Enum.map(fn {:ok, html} -> html end)

    assert Enum.sort(results) == Enum.sort(Enum.map(1..100, &"rollover-#{&1}"))
    assert :ets.info(FragmentCache, :size) <= 4096
  end
end
