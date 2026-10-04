defmodule Campfire.MentionsTest do
  use ExUnit.Case, async: false
  alias Campfire.{Chat, DB, Rails, RichText}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))
  setup do
    DB.restore_fixture(@fixture)
    :ok
  end

  test "valid mention SGIDs expand and store searchable plain text outside the transaction" do
    sgid = Rails.attachable_sgid("User", 127_326_141)

    html =
      ~s(<p>Hello <action-text-attachment sgid="#{sgid}" content-type="application/vnd.campfire.mention"></action-text-attachment> world.</p>)

    assert RichText.plain_text(html) == "Hello @David world."
    assert RichText.render(html) =~ ~s(<span class="mention" sgid="#{sgid}">)
    assert RichText.render(html) =~ ~s(href="/users/127326141")
    bot = Chat.bot("394959859-BenderBot123")
    room = Chat.room(bot, 486_777_696)
    message = Chat.create_message(bot, room, html)

    assert DB.one("SELECT body FROM message_search_index WHERE rowid=?", [message["id"]])["body"] ==
             "Hello @David world."
  end
end
