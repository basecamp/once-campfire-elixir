defmodule Campfire.Mime do
  @external_resource "priv/compat/marcel.json"
  @tables Jason.decode!(File.read!(@external_resource))
  @binary "application/octet-stream"

  def identify(bytes, name \\ nil, declared \\ nil) do
    candidates = [
      magic(bytes),
      declared(declared),
      name && extension(Campfire.Filename.extension(name)),
      @binary
    ]

    [first | rest] = Enum.reject(candidates, &is_nil/1) |> Enum.uniq()

    Enum.reduce(rest, first, fn candidate, current ->
      if child?(candidate, current), do: candidate, else: current
    end)
  end

  def extension(ext), do: @tables["extensions"][String.downcase(String.trim_leading(ext, "."))]
  def extensions(type), do: @tables["type_exts"][type] || []

  def child?(child, parent),
    do: child == parent || Enum.any?(@tables["parents"][child] || [], &child?(&1, parent))

  defp declared(nil), do: nil

  defp declared(value) do
    value = String.downcase(value) |> String.split(~r/[;,\s]/, parts: 2) |> hd()
    if String.contains?(value, "/") && value != @binary, do: value
  end

  defp magic(bytes) do
    Enum.find_value(@tables["magic"], fn [type, matches] ->
      if matches?(bytes, matches), do: String.downcase(type)
    end)
  end

  defp matches?(bytes, matches) do
    Enum.any?(matches, fn entry ->
      if entry["hex"] do
        value = Base.decode16!(entry["hex"], case: :lower)
        offset = entry["offset"]

        count =
          if entry["range_end"],
            do: entry["range_end"] - offset + byte_size(value),
            else: byte_size(value)

        read =
          cond do
            count == 0 -> ""
            offset >= byte_size(bytes) -> nil
            true -> binary_part(bytes, offset, min(count, byte_size(bytes) - offset))
          end

        hit =
          if entry["range_end"],
            do: read && (value == "" || :binary.match(read, value) != :nomatch),
            else: read == value

        hit && (entry["children"] == [] || matches?(bytes, entry["children"]))
      else
        false
      end
    end)
  end
end
