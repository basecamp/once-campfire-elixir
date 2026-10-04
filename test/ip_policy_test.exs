defmodule Campfire.IPPolicyTest do
  use ExUnit.Case, async: true
  @vectors Jason.decode!(File.read!("vectors/ip_policy.json"))
  for {v, index} <- Enum.with_index(@vectors["data"]) do
    @case v
    test "Surfguard boundary #{index}" do
      {:ok, ip} = :inet.parse_address(String.to_charlist(@case["ip"]))
      assert Campfire.IPPolicy.public?(ip) == @case["public"], @case["ip"]
    end
  end
end
