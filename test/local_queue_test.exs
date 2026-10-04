defmodule Campfire.LocalQueueTest do
  use ExUnit.Case, async: false
  alias Campfire.{Cable, Chat, DB, LocalQueue, Worker}
  @fixture Jason.decode!(File.read!("test/fixtures/seed.json"))

  setup do
    DB.restore_fixture(@fixture)
    :ok
  end

  test "worker drains the in-process queue without Redis" do
    bot = Chat.bot("394959859-BenderBot123")
    room = DB.one("SELECT * FROM rooms WHERE id=486777696")
    message = Chat.create_message(bot, room, "<p>queued needle</p>")

    before = LocalQueue.stats()

    System.delete_env("CAMPFIRE_JOBS_ADAPTER")

    try do
      Campfire.Jobs.enqueue("RemoveBannedContentJob", [
        %{"_aj_globalid" => "gid://campfire/User/#{bot["id"]}"}
      ])
    after
      System.put_env("CAMPFIRE_JOBS_ADAPTER", "disabled")
    end

    assert LocalQueue.stats()["queued"] == before["queued"] + 1
    assert {:noreply, _} = Worker.handle_info(:poll, %{worker: "test"})
    assert LocalQueue.stats()["queued"] == before["queued"]
    assert LocalQueue.stats()["processed"] == before["processed"] + 1
    assert LocalQueue.stats()["failed"] == before["failed"]
    refute DB.one("SELECT id FROM messages WHERE id=?", [message["id"]])
  end

  test "broadcasts encode one frame per subscription identifier" do
    stream = "test_stream_#{System.unique_integer([:positive])}"
    Registry.register(Campfire.Streams, stream, ~s({"channel":"RoomChannel"}))
    Cable.broadcast(stream, %{"hello" => "<world>"})
    assert_receive {:frame, frame}

    assert Jason.decode!(frame) == %{
             "identifier" => ~s({"channel":"RoomChannel"}),
             "message" => %{"hello" => "<world>"}
           }

    assert frame =~ "\\u003cworld\\u003e"
  end
end
