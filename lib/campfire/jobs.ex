defmodule Campfire.Jobs do
  @moduledoc "Resque-compatible post-commit enqueueing for the native queue consumer."
  require Logger

  def enqueue_push(room, message) do
    enqueue("Room::PushMessageJob", [
      %{"_aj_globalid" => "gid://campfire/#{room["type"]}/#{room["id"]}"},
      %{"_aj_globalid" => "gid://campfire/Message/#{message["id"]}"}
    ])
  end

  def enqueue(class, args) do
    cond do
      System.get_env("CAMPFIRE_JOBS_ADAPTER") == "disabled" -> :ok
      is_nil(Process.whereis(Campfire.Redis)) -> enqueue_error(:redis_unavailable)
      true -> enqueue_redis(class, args)
    end
  end

  defp enqueue_redis(class, args) do
    now = Campfire.Clock.now()
    micros = elem(now.microsecond, 0) |> to_string() |> String.pad_leading(6, "0")
    enqueued_at = Calendar.strftime(now, "%Y-%m-%dT%H:%M:%S") <> "." <> micros <> "000Z"

    job = %{
      "job_class" => class,
      "job_id" => Campfire.Chat.uuid(),
      "provider_job_id" => nil,
      "queue_name" => "default",
      "priority" => nil,
      "arguments" => args,
      "executions" => 0,
      "exception_executions" => %{},
      "locale" => "en",
      "timezone" => "UTC",
      "enqueued_at" => enqueued_at,
      "scheduled_at" => nil
    }

    wrapper = %{
      "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
      "args" => [job]
    }

    case Redix.transaction_pipeline(Campfire.Redis, [
           ["SADD", "resque:queues", "default"],
           ["RPUSH", "resque:queue:default", Campfire.Rails.json(wrapper)]
         ]) do
      {:ok, _} -> :ok
      {:error, error} -> enqueue_error(error)
    end
  catch
    :exit, {:redix_exited_during_call, reason} ->
      enqueue_error({:redis_unavailable, reason})
  end

  defp enqueue_error(error) do
    Logger.error("Campfire job enqueue failed: #{inspect(error)}")
    {:error, error}
  end
end
