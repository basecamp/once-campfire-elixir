defmodule Campfire.SigilsTest do
  use ExUnit.Case, async: true
  import Kernel, except: [sigil_r: 2]
  import Campfire.Sigils

  test "literal regexes reuse one runtime compilation with the same matching semantics" do
    for _ <- 1..20 do
      regex = ~r/\A[[:alpha:]]+\z/iu
      assert regex == Campfire.Sigils.regex({regex.source, regex.opts})
      assert Regex.match?(regex, "Café")
      refute Regex.match?(regex, "123")
    end
  end

  test "interpolated patterns remain dynamic" do
    for value <- ["alpha", "beta"] do
      assert Regex.match?(~r/^#{value}$/, value)
      refute Regex.match?(~r/^#{value}$/, "other")
    end
  end
end
