require "minitest/autorun"
require "open3"
require "json"

class CheckSampleTest < Minitest::Test
  def test_rejects_missing_validation_and_every_kind_of_unsuccessful_sample
    good = { "errors" => 0, "invalid_responses" => 0, "validation" => "route-contract-v1", "ok" => 8, "statuses" => { "200" => 8 } }
    bad = [good.reject { |key, _| key == "invalid_responses" }, good.reject { |key, _| key == "validation" },
      good.merge("validation" => "status-only"), good.merge("invalid_responses" => 1),
      good.merge("errors" => 1), good.merge("statuses" => { "200" => 7 }), good.merge("ok" => 0), good.merge("statuses" => { "200" => 7, "500" => 1 })]
    bad.each do |value|
      _, _, status = Open3.capture3(RbConfig.ruby, File.join(__dir__, "check_sample.rb"), stdin_data: JSON.generate(value))
      refute status.success?, value.inspect
    end
    output, errors, status = Open3.capture3(RbConfig.ruby, File.join(__dir__, "check_sample.rb"), stdin_data: JSON.generate(good))
    assert status.success?, errors
    assert_equal good, JSON.parse(output)
  end
  def test_rejects_cable_errors_and_partial_fanout
    sample = { "post_attempts" => 4, "post_errors" => 0, "complete" => 4 }
    good = { "clients" => 2, "ready" => 2, "failed" => 0, "latency" => sample.merge("messages" => 4), "throughput" => sample.merge("posted" => 4) }
    values = [good.merge("ready" => 1), good.merge("failed" => 1), good.merge("latency" => good["latency"].merge("post_errors" => 1)), good.merge("throughput" => good["throughput"].merge("complete" => 3)), good.merge("throughput" => good["throughput"].merge("post_attempts" => 5))]
    values.each do |value|
      _, _, status = Open3.capture3(RbConfig.ruby, File.join(__dir__, "check_sample.rb"), "cable", stdin_data: JSON.generate(value))
      refute status.success?, value.inspect
    end
    _, errors, status = Open3.capture3(RbConfig.ruby, File.join(__dir__, "check_sample.rb"), "cable", stdin_data: JSON.generate(good))
    assert status.success?, errors
  end

end
