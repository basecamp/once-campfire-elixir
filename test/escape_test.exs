defmodule Campfire.EscapeTest do
  use ExUnit.Case, async: true
  alias Campfire.Escape

  defp chain(value, pairs),
    do: Enum.reduce(pairs, value, fn {m, r}, v -> String.replace(v, m, r) end)

  @text [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {" ", "&nbsp;"}]
  @html [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {"\"", "&quot;"}, {"'", "&#39;"}]

  test "matches the chained replacements it replaced, including invalid UTF-8" do
    alphabet = [?a, ?&, ?<, ?>, ?", ?', 0xC2, 0xA0, 0xE2, ?\n]

    for _ <- 1..2_000 do
      value = for _ <- 1..:rand.uniform(24), into: <<>>, do: <<Enum.random(alphabet)>>
      assert Escape.text(value) == chain(value, @text)
      assert Escape.attr(value) == chain(value, @text ++ [{"\"", "&quot;"}])
      assert Escape.html(value) == chain(value, @html)
    end
  end

  test "returns text without escapes unchanged" do
    value = "plain text"
    assert :erts_debug.same(Escape.text(value), value)
  end
end
