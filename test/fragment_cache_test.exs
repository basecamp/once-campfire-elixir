defmodule Campfire.FragmentCacheTest do
  use ExUnit.Case, async: false
  alias Campfire.FragmentCache

  test "caching survives a concurrent wipe that removed the byte counter" do
    # Another process's eviction runs delete_all_objects before re-inserting the counter.
    :ets.delete(FragmentCache, :bytes)
    message = %{"id" => -1, "updated_at" => "2026-10-05 00:00:00"}

    assert FragmentCache.record(:message, message, fn -> "<div>cached</div>" end) ==
             "<div>cached</div>"

    assert FragmentCache.record(:message, message, fn -> flunk("rendered twice") end) ==
             "<div>cached</div>"
  end

  test "concurrent stores past the limit keep the count exact and evict only part" do
    table = Campfire.FragmentCache.Memo
    FragmentCache.set_limit(table, 20_000)

    on_exit(fn ->
      FragmentCache.set_limit(table, 64 * 1024 * 1024)
    end)

    1..40
    |> Task.async_stream(
      fn i ->
        for j <- 1..25,
            do: FragmentCache.memo({:accounting, i, j}, 100, fn -> :binary.copy("x", 100) end)
      end,
      max_concurrency: 40
    )
    |> Stream.run()

    present = :ets.select(table, [{{:_, :_, :_, :_, :"$1"}, [], [:"$1"]}]) |> Enum.sum()
    assert FragmentCache.bytes(table) == present
    assert present <= 20_000

    kept = :ets.select_count(table, [{{{:accounting, :_, :_}, :_, :_, :_, :_}, [], [true]}])
    assert kept > 0 and kept < 1000
  end

  test "a newer version replaces a fragment's count, and derived pieces are counted" do
    before = FragmentCache.bytes(FragmentCache)
    first = %{"id" => -2, "updated_at" => "1"}
    second = %{"id" => -2, "updated_at" => "2"}

    assert FragmentCache.record(:message, first, fn -> "aaaa" end) == "aaaa"
    assert FragmentCache.bytes(FragmentCache) == before + 4

    assert FragmentCache.record(:message, second, fn -> "bbbbbbbb" end) == "bbbbbbbb"
    assert FragmentCache.bytes(FragmentCache) == before + 8

    assert FragmentCache.derived({:message, -2}, "2", "bbbbbbbb", :x, fn _ -> "123" end) == "123"
    assert FragmentCache.bytes(FragmentCache) == before + 11

    assert FragmentCache.derived({:message, -2}, "2", "bbbbbbbb", :x, fn _ -> flunk() end) ==
             "123"
  end
end
