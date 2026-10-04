defmodule Campfire.MimeTest do
  use ExUnit.Case, async: true
  @vectors Jason.decode!(File.read!("vectors/storage.json"))["marcel"]
  for {vector, index} <- Enum.with_index(@vectors) do
    @vector vector
    test "Marcel source vector #{index}" do
      bytes =
        if @vector["data_hex"],
          do: Base.decode16!(@vector["data_hex"], case: :mixed),
          else: File.read!("reference/test/fixtures/files/" <> @vector["fixture"])

      assert Campfire.Mime.identify(bytes, @vector["name"], @vector["declared_type"]) ==
               @vector["content_type"]
    end
  end
end
