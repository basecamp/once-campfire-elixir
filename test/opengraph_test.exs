defmodule Campfire.OpengraphTest do
  use ExUnit.Case, async: true

  for {entry, index} <-
        Enum.with_index(Jason.decode!(File.read!("vectors/opengraph-document.json"))) do
    test "pinned OpenGraph document #{index}" do
      entry = unquote(Macro.escape(entry))
      assert Campfire.Opengraph.attributes(entry["html"]) == entry["attributes"]
    end
  end

  for {entry, index} <-
        Enum.with_index(Jason.decode!(File.read!("vectors/opengraph-metadata.json"))) do
    test "pinned OpenGraph metadata #{index}" do
      entry = unquote(Macro.escape(entry))

      valid_url = fn
        value when is_binary(value) -> URI.parse(value).scheme in ["http", "https"]
        _ -> false
      end

      result =
        Campfire.Opengraph.metadata(entry["html"], entry["url"],
          valid_url: valid_url,
          image_type: fn _ -> entry["image_type"] end
        )

      if entry["valid"] do
        assert {:ok, fields} = result
        assert Campfire.Rails.json(fields) == entry["json"]
      else
        assert result == :invalid
      end
    end
  end
end
