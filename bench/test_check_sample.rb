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
end
