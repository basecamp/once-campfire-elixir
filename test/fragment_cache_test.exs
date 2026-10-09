defmodule Campfire.FragmentCacheTest do
  use ExUnit.Case, async: true
  alias Campfire.FragmentCache

  test "spliced pages keep their exact bytes and parts" do
    marker = "<!--fragments-->"
    fragments = for i <- 1..3, do: {:fragment, nil, "<div>#{i}</div>\n"}
    html = "<html><body>\n" <> marker <> "</body></html>\n"

    {body, parts} = FragmentCache.splice(html, marker, fragments)

    assert IO.iodata_to_binary(body) ==
             String.replace(html, marker, Enum.map_join(fragments, &elem(&1, 2)))

    assert parts == [{:raw, "<html><body>\n"} | fragments] ++ [{:raw, "</body></html>\n"}]
  end

  test "a missing marker is reported" do
    assert FragmentCache.splice("<html></html>", "<!--fragments-->", []) == nil
  end

  test "derived values are computed directly for uncached fragments" do
    assert FragmentCache.derived(nil, :digest, "html", &String.upcase/1) == "HTML"
  end
end
