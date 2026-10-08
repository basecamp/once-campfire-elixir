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

  test "cached message fragments are complete immutable token-free HTML", %{message: message} do
    first = MessagesView.render(message, "https://campfire.test")
    assert first == MessagesView.render(message, "https://campfire.test")
    refute first =~ ~s(name="authenticity_token")
  end

  test "batch rendering shares complete fragments with broadcasts" do
    messages = DB.query("SELECT * FROM messages ORDER BY id DESC LIMIT 2")
    assert length(messages) == 2
    base = "https://campfire.test"
    html = MessagesView.render_many(messages, base)
    assert html == Enum.map_join(messages, &MessagesView.render(&1, base))
    refute html =~ ~s(name="authenticity_token")
    assert MessagesView.render_many([], base) == ""
  end

  test "batch rendering isolates a failed item" do
    [first, second] = DB.query("SELECT * FROM messages ORDER BY id LIMIT 2")
    base = "https://campfire.test"
    failed_message = %{second | "creator_id" => -1}
    failed = MessagesView.render(failed_message, base)
    assert failed =~ "Failed to load message content"

    assert MessagesView.render_many([first, failed_message, second], base) ==
             MessagesView.render(first, base) <> failed <> MessagesView.render(second, base)
  end

  test "cached boosts are complete immutable token-free HTML" do
    boost = DB.one("SELECT * FROM boosts ORDER BY id LIMIT 1")
    first = MessagesView.render_boost(boost)
    assert first == MessagesView.render_boost(boost)
    refute first =~ ~s(name="authenticity_token")
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
