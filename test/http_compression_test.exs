defmodule Campfire.HttpCompressionTest do
  use ExUnit.Case, async: true
  alias Campfire.HttpCompression

  test "spliced pages gzip to the exact rendered bytes" do
    marker = "<!--fragments-->"

    fragments =
      for i <- 1..40, do: {:raw, String.duplicate("<div class=\"message\">#{i}</div>\n", i)}

    html = "<html><head></head><body>\n" <> marker <> "</body></html>\n"

    {body, parts} = HttpCompression.splice(html, marker, fragments)
    expected = String.replace(html, marker, Enum.map_join(fragments, &elem(&1, 1)))

    assert IO.iodata_to_binary(body) == expected
    assert :zlib.gunzip(IO.iodata_to_binary(HttpCompression.gzip_parts(parts))) == expected
  end

  test "empty pieces and binary data remain valid" do
    parts = [{:raw, ""}, {:raw, :crypto.strong_rand_bytes(70_000)}, {:raw, ""}]
    expected = Enum.map_join(parts, &elem(&1, 1))
    assert :zlib.gunzip(IO.iodata_to_binary(HttpCompression.gzip_parts(parts))) == expected
  end

  test "cached fragment pieces are reused only after the same predecessor" do
    fragment = fn id, version, text ->
      [part] =
        Campfire.FragmentCache.parts(
          :message,
          [%{"id" => "compression-test-#{id}", "updated_at" => version}],
          fn _ -> text end
        )

      part
    end

    a = fn -> fragment.(1, "v1", String.duplicate("<p>alpha</p>\n", 50)) end
    b = fn -> fragment.(2, "v1", String.duplicate("<p>beta</p>\n", 50)) end
    b2 = fn -> fragment.(2, "v2", String.duplicate("<p>beta two</p>\n", 50)) end
    c = fn -> fragment.(3, "v1", String.duplicate("<p>gamma</p>\n", 50)) end

    for parts <- [
          [a, b, c],
          [a, b, c],
          [b, a, c],
          [{:raw, "<head>"}, a, b, c, {:raw, "</html>"}],
          [{:raw, "<other head>"}, a, b2, c, {:raw, "</html>"}],
          [a, b2, c],
          [a, b, c]
        ] do
      parts = Enum.map(parts, fn part -> if is_function(part), do: part.(), else: part end)
      expected = Enum.map_join(parts, &body/1)
      assert :zlib.gunzip(IO.iodata_to_binary(HttpCompression.gzip_parts(parts))) == expected
    end
  end

  defp body({:raw, data}), do: data
  defp body({:fragment, _, _, html}), do: html

  test "a missing marker is reported" do
    assert HttpCompression.splice("<html></html>", "<!--fragments-->", []) == nil
  end
end
