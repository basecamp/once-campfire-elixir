require "json"
value = JSON.parse(STDIN.read)
raise "Invalid benchmark sample: #{value}" unless value.fetch("errors").zero? && value.fetch("invalid_responses").zero? && value.fetch("validation") == "route-contract-v1" && value.fetch("ok") > 0 && value.fetch("statuses") == { "200" => value.fetch("ok") }
puts JSON.generate(value)
