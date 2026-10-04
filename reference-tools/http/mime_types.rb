require "json"
puts JSON.pretty_generate({ canonical: Mime::SET.to_h { |type| [type.symbol.to_s, type.to_s] }, lookup: Mime::LOOKUP.transform_values { |type| type.symbol.to_s }, wildcards: %w[text application].to_h { |group| [group, Mime::Type.parse_data_with_trailing_star(group).map { |type| type.symbol.to_s }] } })
