defmodule Campfire.SoundsTest do
  use ExUnit.Case, async: true
  @vectors Jason.decode!(File.read!("vectors/sounds.json"))
  for vector <- @vectors do
    @vector vector
    test "source sound presentation #{@vector["name"]}" do
      assert sound = Campfire.Sounds.find("/play " <> @vector["name"])
      assert Campfire.Sounds.render(sound) == @vector["presentation"]
    end
  end

  test "commands require an exact known sound" do
    refute Campfire.Sounds.find("/play nonexistent")
    refute Campfire.Sounds.find("before /play bell")
    refute Campfire.Sounds.find("/play bell after")
  end
end
