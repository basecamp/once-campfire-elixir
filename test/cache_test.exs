defmodule Campfire.CacheTest do
  use ExUnit.Case, async: true
  alias Campfire.Rails.Cache

  for {entry, index} <- Enum.with_index(Jason.decode!(File.read!("vectors/cache-entries.json"))) do
    test "pinned Active Support string entry #{index}" do
      entry = unquote(Macro.escape(entry))
      raw = Base.decode64!(entry["base64"])
      assert Cache.dump(entry["value"], entry["version"], entry["expires"] || -1.0) == raw

      if entry["expires"] == 1_000_000_000.0 do
        assert Cache.load(raw, entry["version"]) == :miss
      else
        assert Cache.load(raw, entry["version"]) == {:ok, entry["value"]}
      end

      assert Cache.load(raw, "another version") == :miss
    end
  end

  test "truncated, corrupt and object entries remain cache misses" do
    assert Cache.load(<<0, 17>>, nil) == :miss

    assert Cache.load(<<0, 17, 1, -1.0::little-float-64, -1::little-signed-32, 4, 8>>, nil) ==
             :miss

    assert Cache.load(
             <<0, 17, 130, -1.0::little-float-64, -1::little-signed-32, "invalid zlib">>,
             nil
           ) == :miss
  end
end
