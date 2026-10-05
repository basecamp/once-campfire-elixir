defmodule Campfire.Rails.Cache do
  @moduledoc "Active Support 7.1 cache entries for strings, without object deserialization."
  import Bitwise

  def dump(value, version, expires \\ -1.0) do
    compressed = :zlib.compress(value)

    {flag, payload} =
      if byte_size(value) >= 1024 && byte_size(compressed) < byte_size(value),
        do: {130, compressed},
        else: {2, value}

    length = if is_nil(version), do: -1, else: byte_size(version)

    <<0, 17, flag, expires::little-float-size(64), length::little-signed-size(32),
      version || ""::binary, payload::binary>>
  end

  def load(
        <<0, 17, flag, expires::little-float-size(64), length::little-signed-size(32),
          rest::binary>>,
        version
      ) do
    size = max(length, 0)

    with true <- (flag &&& 127) in [2, 3, 4],
         true <- expires < 0 || expires > DateTime.to_unix(Campfire.Clock.now()),
         <<stored::binary-size(^size), payload::binary>> <- rest,
         true <- if(length < 0, do: nil, else: stored) == version do
      value = if (flag &&& 128) != 0, do: :zlib.uncompress(payload), else: payload
      {:ok, value}
    else
      _ -> :miss
    end
  rescue
    _ -> :miss
  end

  def load(_, _), do: :miss
end
