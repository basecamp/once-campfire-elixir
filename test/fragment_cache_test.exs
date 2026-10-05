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
end
