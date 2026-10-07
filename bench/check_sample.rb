require "json"
value = JSON.parse(STDIN.read)
if ARGV.first == "cable"
  raise "Incomplete Cable subscriptions" unless value.fetch("ready") == value.fetch("clients") && value.fetch("failed").zero?
  { "latency" => "messages", "throughput" => "posted" }.each do |phase, count|
    sample = value.fetch(phase)
    posted = sample.fetch(count)
    raise "Unsuccessful Cable messages: #{sample}" unless posted.positive? && sample.fetch("post_attempts") == posted && sample.fetch("post_errors").zero? && sample.fetch("complete") == posted
  end
else
  raise "Invalid benchmark sample: #{value}" unless value.fetch("errors").zero? && value.fetch("invalid_responses").zero? && value.fetch("validation") == "route-contract-v1" && value.fetch("ok") > 0 && value.fetch("statuses") == { "200" => value.fetch("ok") }
end
puts JSON.generate(value)
