defmodule Campfire.FragmentKeysTest do
  use ExUnit.Case, async: false
  alias Campfire.{DB, FragmentCache, MessagesView}
  alias Exqlite.Sqlite3, as: SQL
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  # A closed-room message whose presentation is its rich-text body.
  @plain 217_777_555
  # A message with a boost and an attachment.
  @boosted 933_434_498

  setup do
    :ok = DB.restore_fixture(@fixture)
    :ok = FragmentCache.clear()
    {:ok, foreign} = SQL.open(System.fetch_env!("DATABASE_PATH"))
    on_exit(fn -> SQL.close(foreign) end)
    on_exit(fn -> Process.delete(:campfire_request_base) end)
    %{foreign: foreign}
  end

  defp size, do: FragmentCache.size()

  defp message(id), do: DB.one("SELECT * FROM messages WHERE id=?", [id])

  defp render(id, base \\ "https://campfire.test") do
    Process.put(:campfire_request_base, base)
    MessagesView.render(message(id), base)
  end

  test "a fragment is reused while its generation and origin hold" do
    first = render(@boosted)
    entries = size()
    assert entries > 0
    assert render(@boosted) == first
    assert size() == entries
  end

  test "any commit retires a fragment, even from another room", %{foreign: foreign} do
    first = render(@boosted)
    entries = size()

    :ok =
      SQL.execute(
        foreign,
        "INSERT INTO messages (id,room_id,creator_id,client_message_id,created_at,updated_at) VALUES (999999999,104393281,127326141,'unrelated','2026-03-02 16:30:00','2026-03-02 16:30:00')"
      )

    assert render(@boosted) == first
    assert size() > entries
  end

  test "an unversioned foreign write is visible in the next render", %{foreign: foreign} do
    assert render(@plain) =~ "loyal to the people who pay them"

    :ok =
      SQL.execute(
        foreign,
        "UPDATE action_text_rich_texts SET body='<p>foreign body</p>' WHERE record_id=#{@plain}"
      )

    assert render(@plain) =~ "foreign body"
  end

  test "a fragment belongs to the origin its links carry" do
    first = render(@plain, "https://one.test")
    assert first =~ "https://one.test/rooms/"
    entries = size()

    other = render(@plain, "https://two.test")
    assert other =~ "https://two.test/rooms/"
    refute other == first
    assert size() == entries + 1
    assert render(@plain, "https://one.test") == first
    assert size() == entries + 1
  end

  test "renders outside a request share one scope" do
    Process.delete(:campfire_request_base)
    first = MessagesView.render(message(@plain), "http://example.org")
    entries = size()
    assert MessagesView.render(message(@plain), "http://example.org") == first
    assert size() == entries

    refute render(@plain, "https://one.test") == first
    assert size() == entries + 1
  end

  test "a boost fragment follows its generation too", %{foreign: foreign} do
    boost = DB.one("SELECT * FROM boosts WHERE message_id=?", [@boosted])
    assert MessagesView.render_boost(boost) =~ boost["content"]

    :ok =
      SQL.execute(
        foreign,
        "UPDATE users SET name='Renamed Booster' WHERE id=#{boost["booster_id"]}"
      )

    assert MessagesView.render_boost(boost) =~
             "Renamed Booster"
  end
end

defmodule Campfire.FragmentBatchTest do
  use ExUnit.Case, async: false
  alias Campfire.{DB, FragmentCache}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    :ok = DB.restore_fixture(@fixture)
    :ok = FragmentCache.clear()
    on_exit(fn -> Process.delete(:campfire_request_base) end)
    Process.put(:campfire_request_base, "https://campfire.test")
    %{messages: DB.query("SELECT * FROM messages ORDER BY id LIMIT 4")}
  end

  defp render(value), do: "<p>#{value}</p>"

  test "a cold batch renders every entry, stores them, and serves the next batch without rendering",
       %{messages: messages} do
    entries = Enum.map(messages, &{:message, &1})
    parent = self()

    rendered =
      FragmentCache.fetch_many(entries, fn missed ->
        send(parent, {:rendered, length(missed)})
        Enum.map(missed, fn {:message, message} -> render(message["id"]) end)
      end)

    assert_received {:rendered, 4}
    assert rendered == Enum.map(messages, &render(&1["id"]))
    assert FragmentCache.size() == 4

    again =
      FragmentCache.fetch_many(entries, fn missed ->
        send(parent, {:rendered, length(missed)})
        Enum.map(missed, fn {:message, message} -> render(message["id"]) end)
      end)

    refute_received {:rendered, _}
    assert again == rendered
  end

  test "a batch renders and passes only what is missing, in entry order", %{messages: messages} do
    [first, second | _] = messages
    entries = Enum.map(messages, &{:message, &1})

    assert FragmentCache.fetch_many([{:message, first}], fn [{:message, m}] ->
             [render(m["id"])]
           end) ==
             [render(first["id"])]

    assert FragmentCache.fetch_many(entries, fn missed ->
             send(self(), {:missed, missed})
             Enum.map(missed, fn {:message, message} -> render(message["id"]) end)
           end) == Enum.map(messages, &render(&1["id"]))

    assert_received {:missed, missed}
    assert missed == [{:message, second} | Enum.map(Enum.drop(messages, 2), &{:message, &1})]
  end

  test "an empty batch renders nothing" do
    assert FragmentCache.fetch_many([], fn _ -> flunk("should not render") end) == []
  end

  test "entries larger than a quarter of the limit are served but not kept", %{
    messages: [_ | _] = messages
  } do
    previous = Campfire.Env.get("CAMPFIRE_FRAGMENT_CACHE_MB")
    Campfire.Env.put("CAMPFIRE_FRAGMENT_CACHE_MB", "0")

    on_exit(fn ->
      if previous,
        do: Campfire.Env.put("CAMPFIRE_FRAGMENT_CACHE_MB", previous),
        else: Campfire.Env.delete("CAMPFIRE_FRAGMENT_CACHE_MB")
    end)

    entries = Enum.take(messages, 2) |> Enum.map(&{:message, &1})

    html =
      FragmentCache.fetch_many(entries, fn missed ->
        Enum.map(missed, fn {:message, message} -> render(message["id"]) end)
      end)

    assert html == Enum.map(entries, fn {:message, message} -> render(message["id"]) end)
    assert FragmentCache.size() == 0
  end
end
