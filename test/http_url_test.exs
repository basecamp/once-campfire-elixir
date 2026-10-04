defmodule Campfire.HttpURLTest do
  use ExUnit.Case, async: true
  @vectors Jason.decode!(File.read!("vectors/url-shapes.json"))
  for {vector, index} <- Enum.with_index(@vectors) do
    test "URI::HTTP captured input #{index}" do
      assert match?({:ok, _}, Campfire.HttpURL.parse(unquote(vector["url"]))) ==
               unquote(vector["valid"])
    end
  end
end
