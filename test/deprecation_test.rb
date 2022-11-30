require "test_helper"

class DeprecationTest < Minitest::Spec
  it do
    caller_location = caller_locations[0]

    _, err = capture_io do
      Trailblazer::Activity::Deprecate.warn caller_location, "so 90s!"
    end

    assert_equal err, %{[Trailblazer] #{File.absolute_path(caller_location.absolute_path)}:#{caller_location.lineno} so 90s!\n}
  end
end
