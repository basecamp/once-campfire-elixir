defmodule Campfire.CookieCodecTest do
  use ExUnit.Case, async: true

  alias Campfire.CookieCodec

  test "encoding matches URI.encode with the unreserved predicate for every byte" do
    for byte <- 0..255 do
      value = <<byte>>
      assert CookieCodec.encode(value) == URI.encode(value, &URI.char_unreserved?/1)
    end
  end

  test "encoding matches on cookie-shaped values and random binaries" do
    assert CookieCodec.encode("abc--def") == URI.encode("abc--def", &URI.char_unreserved?/1)

    for _ <- 1..500 do
      value = :crypto.strong_rand_bytes(:rand.uniform(40))
      assert CookieCodec.encode(value) == URI.encode(value, &URI.char_unreserved?/1)
    end
  end

  test "decoding matches URI.decode including mixed-case escapes" do
    for value <- ["abc", "a%2Fb", "a%2fb", "%41%42", "a+b", "~._-"] do
      assert CookieCodec.decode(value) == URI.decode(value)
    end
  end

  test "malformed escapes pass through exactly as URI.decode leaves them" do
    for value <- ["%", "a%", "%2", "%zz", "%4g", "%4", "%%", "%2G%41"] do
      assert CookieCodec.decode(value) == URI.decode(value)
    end
  end

  test "decoding tolerates bytes URI.decode accepts" do
    for byte <- 0..255, byte != ?% do
      value = <<byte>>
      assert CookieCodec.decode(value) == URI.decode(value)
    end
  end
end
