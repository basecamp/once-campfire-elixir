require "json"
require "surfguard"
names = %i[ IANA_ALLOCATED_IPV6_UNICAST DISALLOWED_IPV4 DISALLOWED_IPV6 GLOBALLY_REACHABLE_IETF_ASSIGNMENTS NAT64_WELL_KNOWN NAT64_LOCAL_USE IPV4_TRANSLATABLE IPV4_COMPATIBLE ]
addresses = names.flat_map do |name|
  value = Surfguard.const_get(name)
  Array(value).flat_map do |network|
    first = network.to_range.first.to_i
    last = network.to_range.last.to_i
    max = network.ipv4? ? (2**32 - 1) : (2**128 - 1)
    [first - 1, first, first + 1, last - 1, last, last + 1].select { |n| n.between?(0, max) }.map { |n| IPAddr.new(n, network.family).to_s }
  end
end
addresses += ["8.8.8.8", "::ffff:8.8.8.8", "64:ff9b::808:808", "64:ff9b::7f00:1", "::ffff:0:8.8.8.8", "127.0.0.1"]
puts "--- RAILS_TO_RUST_JSON_BEGIN ---"
puts JSON.generate(version: 1, kind: "ip-policy", data: addresses.uniq.map { |ip| { ip: ip, public: !Surfguard.blocked_address?(ip) } })
puts "--- RAILS_TO_RUST_JSON_END ---"
