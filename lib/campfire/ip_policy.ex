defmodule Campfire.IPPolicy do
  import Bitwise
  @ranges Jason.decode!(File.read!("priv/ip-policy.json"))
  def public?({a, b, c, d} = ip) do
    if Enum.all?(Tuple.to_list(ip), &(is_integer(&1) && &1 in 0..255)) do
      value = (a <<< 24) + (b <<< 16) + (c <<< 8) + d
      !inside?(value, "DISALLOWED_IPV4")
    else
      false
    end
  end

  def public?(ip) when is_tuple(ip) and tuple_size(ip) == 8 do
    if Enum.all?(Tuple.to_list(ip), &(is_integer(&1) && &1 in 0..65535)) do
      value = Tuple.to_list(ip) |> Enum.reduce(0, fn part, acc -> (acc <<< 16) + part end)

      cond do
        inside?(value, "IPV4_MAPPED") || inside?(value, "IPV4_COMPATIBLE") ||
            inside?(value, "NAT64_LOCAL_USE") ->
          false

        inside?(value, "NAT64_WELL_KNOWN") || inside?(value, "IPV4_TRANSLATABLE") ->
          !inside?(band(value, 0xFFFFFFFF), "DISALLOWED_IPV4")

        inside?(value, "GLOBALLY_REACHABLE_IETF_ASSIGNMENTS") ->
          true

        inside?(value, "IETF_PROTOCOL_ASSIGNMENTS") || inside?(value, "DISALLOWED_IPV6") ->
          false

        true ->
          inside?(value, "IANA_ALLOCATED_IPV6_UNICAST")
      end
    else
      false
    end
  end

  def public?(_), do: false

  defp inside?(value, name),
    do: Enum.any?(@ranges[name], fn [first, last] -> value >= first && value <= last end)
end
