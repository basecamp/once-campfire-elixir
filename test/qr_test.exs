defmodule Campfire.QRTest do
  use ExUnit.Case, async: true
  @vectors Jason.decode!(File.read!("vectors/qr.json"))
  for {row, i} <- Enum.with_index(@vectors) do
    @row row
    test "captured RQRCode SVG #{i}" do
      text = Base.decode64!(@row["base64"])

      if @row["error"] do
        assert {:error, _} = Campfire.QR.svg(text)
      else
        assert {:ok, %{version: version, mask: mask}} = Campfire.QR.matrix(text)
        assert version == @row["version"]
        assert mask == @row["mask"]
        assert Campfire.QR.svg(text) == {:ok, @row["svg"]}
      end
    end
  end
end
