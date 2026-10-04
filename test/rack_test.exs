defmodule Campfire.RackTest do
  use ExUnit.Case, async: true
  @vectors Jason.decode!(File.read!("vectors/ruby_core.json"))["byte_ranges"]
  for {v, index} <- Enum.with_index(@vectors) do
    @v v
    test "Rack byte ranges #{index}" do
      assert Campfire.Rack.ranges(@v["header"], @v["size"]) == @v["ranges"], inspect(@v)
    end
  end
end
