defmodule Campfire.FrontCacheTest do
  use ExUnit.Case, async: false
  import Plug.Test
  alias Campfire.Front.Cache

  setup do
    Cache.clear()
    :ok
  end

  defp counted, do: :atomics.get(:persistent_term.get({Cache, :size}), 1)
  defp stored, do: :ets.foldl(fn {_, _, size, _, _, _, _, _}, sum -> sum + size end, 0, Cache)

  test "the size counter matches the entries after concurrent stores of one key" do
    config = %Campfire.Front.Config{
      cache_size: 64 * 1024 * 1024,
      max_cache_item_size: 1024 * 1024
    }

    conn = conn(:get, "/public")
    headers = [{"content-type", "text/plain"}, {"cache-control", "public, max-age=60"}]
    now = System.monotonic_time(:millisecond)

    tasks =
      for i <- 1..32 do
        Task.async(fn ->
          for n <- 1..200 do
            body = String.duplicate("x", 100 + rem(i * n, 7))

            Cache.store(
              conn,
              "GET\n/public\n\ncampfire.test",
              200,
              headers,
              body,
              60_000,
              now,
              config
            )
          end
        end)
      end

    Enum.each(tasks, &Task.await(&1, 60_000))
    assert :ets.info(Cache, :size) == 1
    assert counted() == stored()
  end
end
