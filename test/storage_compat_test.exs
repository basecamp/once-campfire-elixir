defmodule Campfire.StorageCompatTest do
  use ExUnit.Case, async: true
  alias Campfire.{Filename, Marshal, Rails}

  for {item, index} <- Enum.with_index(Jason.decode!(File.read!("vectors/marshal-floats.json"))) do
    @float item
    test "Ruby Marshal float encoding #{index}" do
      assert Base.encode16(Marshal.dump(@float["number"]), case: :lower) == @float["hex"]
    end
  end

  for {item, index} <- Enum.with_index(Jason.decode!(File.read!("vectors/marshal-core.json"))) do
    @core item
    test "Ruby Marshal object links #{index}" do
      assert Base.encode16(Marshal.dump(@core["typed"]), case: :lower) == @core["hex"]
    end
  end

  @vectors Jason.decode!(File.read!("vectors/storage.json"))
  for {f, index} <- Enum.with_index(@vectors["filenames"]) do
    @case f
    test "storage filename vector #{index}" do
      raw = Base.decode16!(@case["input_hex"], case: :mixed)
      assert Filename.sanitized(raw) == @case["sanitized"]
      assert Filename.base(raw) == Base.decode16!(@case["base_hex"], case: :mixed)
      assert Filename.extension(raw) == Base.decode16!(@case["extension_hex"], case: :mixed)
      assert Filename.disposition("inline", raw) == @case["inline"]
      assert Filename.disposition("attachment", raw) == @case["attachment"]
      assert Filename.escape_path(Filename.sanitized(raw)) == @case["escaped_path"]
    end
  end

  for {v, index} <- Enum.with_index(@vectors["variations"]) do
    @case v
    test "storage variation vector #{index}" do
      bytes = Marshal.dump(@case["typed"])
      assert Base.encode16(bytes, case: :lower) == @case["marshal_hex"]
      assert Base.encode64(:crypto.hash(:sha, bytes)) == @case["digest"]

      assert Base.encode16(Marshal.dump(@case["decoded_typed"]), case: :lower) ==
               @case["decoded_marshal_hex"]

      assert Rails.verify_message("ActiveStorage", @case["key"], "variation")
      assert Campfire.StorageMedia.variation_key(@case["typed"]) == @case["key"]
      assert Campfire.StorageMedia.decode_variation(@case["key"]) == {:ok, @case["decoded_typed"]}
    end
  end
end
