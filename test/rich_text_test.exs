defmodule Campfire.RichTextTest do
  use ExUnit.Case, async: true
  @vectors Jason.decode!(File.read!("vectors/richtext.json"))["data"]
  for {v, index} <- Enum.with_index(@vectors) do
    @v v
    test "Rails rich-text #{index}" do
      assert Campfire.RichText.render(@v["input"]) == @v["expected"]["html"]
      assert Campfire.RichText.plain_text(@v["input"]) == @v["expected"]["plain_text"]
    end
  end
end
