defmodule Campfire.JSONTest do
  use ExUnit.Case, async: true
  alias Campfire.JSON

  defp encode(value), do: IO.iodata_to_binary(JSON.encode(value))

  # OTP's escaping with Rails' <, > and & on top, as a multi-pass oracle.
  defp expected(string) do
    string
    |> :json.encode_binary()
    |> IO.iodata_to_binary()
    |> String.replace("<", "\\u003c")
    |> String.replace(">", "\\u003e")
    |> String.replace("&", "\\u0026")
  end

  defp outcome(fun) do
    {:ok, fun.()}
  rescue
    error -> {:error, error}
  end

  test "strings escape like json:encode_binary/1 plus Rails' <, > and &, valid or not" do
    pieces =
      [
        "abcdefgh",
        "<",
        ">",
        "&",
        "\"",
        "\\",
        "/",
        <<0>>,
        <<0x1F>>,
        "\n",
        "é",
        "漢",
        "😀",
        <<0x2028::utf8>>,
        <<0xFF>>,
        <<0xC3>>,
        <<0xE2, 0x82>>,
        <<0xED, 0xA0, 0x80>>,
        <<0xF4, 0x90, 0x80, 0x80>>
      ]

    for _ <- 1..5_000 do
      string = Enum.map_join(1..:rand.uniform(12), fn _ -> Enum.random(pieces) end)
      assert outcome(fn -> encode(string) end) == outcome(fn -> expected(string) end)
    end
  end

  test "values, nil, dates and ordered pairs" do
    assert encode([1, 1.5, true, false, nil, :atom, "<b>"]) ==
             ~s([1,1.5,true,false,null,"atom","\\u003cb\\u003e"])

    assert encode([{"b", 1}, {"a", %{"c" => [{"d", nil}]}}]) == ~s({"b":1,"a":{"c":{"d":null}}})
    assert encode(%{}) == "{}"
    assert encode(~U[2026-03-02 16:00:00Z]) == ~s("2026-03-02T16:00:00Z")
    assert_raise ArgumentError, fn -> encode(URI.parse("http://x")) end
  end

  test "decoding keeps object order and round trips" do
    json = ~s({"z":1,"a":[{"y":null,"b":{}},[]],"m":"<&>"})
    decoded = JSON.decode!(json)
    assert decoded == [{"z", 1}, {"a", [[{"y", nil}, {"b", %{}}], []]}, {"m", "<&>"}]
    assert encode(decoded) == ~s({"z":1,"a":[{"y":null,"b":{}},[]],"m":"\\u003c\\u0026\\u003e"})
    assert JSON.decode!(" {} \n") == %{}
    assert JSON.pairs(%{}) == []
    assert {:error, _} = JSON.decode(~s({"a":1} x))
    assert {:error, _} = JSON.decode("{")
  end
end
