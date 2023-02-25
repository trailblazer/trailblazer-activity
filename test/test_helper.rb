require "pp"
require "trailblazer-activity"
require "minitest/autorun"

Minitest::Spec.class_eval do
  def assert_equal(asserted, expected, *args)
    super(expected, asserted, *args)
  end

  require "trailblazer/activity/testing"
  include Trailblazer::Activity::Testing::Assertions
end

T = Trailblazer::Activity::Testing
