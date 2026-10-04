defmodule Campfire.Random do
  def token(length, alphabet) do
    chars = String.to_charlist(alphabet)
    size = length(chars)
    for _ <- 1..length, into: "", do: <<Enum.at(chars, sample(size))>>
  end

  defp sample(size) do
    <<byte>> = :crypto.strong_rand_bytes(1)
    if byte < div(256, size) * size, do: rem(byte, size), else: sample(size)
  end
end
