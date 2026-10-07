defmodule Campfire.Jobs do
  @moduledoc "Post-commit enqueueing onto the in-process job queue."
  def enqueue_push(room, message) do
    enqueue("Room::PushMessageJob", [
      %{"_aj_globalid" => "gid://campfire/#{room["type"]}/#{room["id"]}"},
      %{"_aj_globalid" => "gid://campfire/Message/#{message["id"]}"}
    ])
  end

  def enqueue(class, args) do
    if System.get_env("CAMPFIRE_JOBS_ADAPTER") == "disabled" do
      :ok
    else
      Campfire.Worker.enqueue(%{"job_class" => class, "arguments" => args})
    end
  end
end
