defmodule Campfire.HtmlParserTest do
  use ExUnit.Case, async: false
  alias Campfire.HtmlParser

  @pathological "<p>" <>
                  Enum.map_join(1..390, &~s(<b a="#{&1}">)) <>
                  String.duplicate("<p>x", 3_000)

  test "parser produces native terms" do
    html = ~s(<p class="message">Hello<!-- pause --><strong>world</strong></p>)

    expected = [
      {"p", [{"class", "message"}], ["Hello", {:comment, " pause "}, {"strong", [], ["world"]}]}
    ]

    assert HtmlParser.parse(html) == expected
  end

  test "large fragments parse on a dirty scheduler without changing output" do
    text = String.duplicate("abcdefgh", 2_049)
    assert [{"p", [], [^text]}] = HtmlParser.parse("<p>#{text}</p>")
    assert HtmlParser.parse_nif("<p>#{text}</p>") == HtmlParser.parse_dirty("<p>#{text}</p>")
  end

  test "valid documents with many nodes retain Rails behavior" do
    for count <- [6_000, 70_000] do
      nodes = HtmlParser.parse(String.duplicate("<p>x</p>", count))
      assert length(nodes) == count
      assert Enum.all?(nodes, &(&1 == {"p", [], ["x"]}))
    end
  end

  test "pathological expansion stops at the allocation limit without stopping the VM" do
    assert_raise ArgumentError, "HTML parser allocation limit exceeded", fn ->
      HtmlParser.parse(@pathological)
    end

    assert HtmlParser.parse("<p>alive</p>") == [{"p", [], ["alive"]}]
  end

  test "failed parses release their memory on every scheduler thread" do
    runs = 2 * System.schedulers_online()

    1..runs
    |> Task.async_stream(fn _ -> HtmlParser.parse_dirty(@pathological) end,
      max_concurrency: runs,
      timeout: 120_000
    )
    |> Enum.each(fn result ->
      assert {:ok, {:error, "HTML parser allocation limit exceeded"}} = result
    end)

    html = String.duplicate("<p>x</p>", 70_000)

    1..runs
    |> Task.async_stream(fn _ -> length(HtmlParser.parse_dirty(html)) end,
      max_concurrency: runs,
      timeout: 120_000
    )
    |> Enum.each(&assert(&1 == {:ok, 70_000}))
  end

  test "concurrent parses do not share allocation state" do
    1..200
    |> Task.async_stream(fn i ->
      html = ~s(<p data-i="#{i}">#{String.duplicate("<i>x</i>", rem(i, 50) + 1)}</p>)
      {i, HtmlParser.parse(html)}
    end)
    |> Enum.each(fn {:ok, {i, [{"p", [{"data-i", value}], children}]}} ->
      assert value == Integer.to_string(i)
      assert length(children) == rem(i, 50) + 1
    end)
  end
end
