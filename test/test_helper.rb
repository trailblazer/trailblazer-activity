require "pp"
require "trailblazer-activity"
require "minitest/autorun"
require "minitest-trailblazer"
require "minitest/trailblazer_spec"

module Minitest
  class TrailblazerSpec
    include Trailblazer::AssertionsOverride
    require "trailblazer/activity/testing"
    include ::Trailblazer::Activity::Testing::Assertions
    require_relative "fixtures"
    include Fixtures

    Spec::Activity = ::Trailblazer::Activity
    Spec::Implementing = Fixtures::Implementing
  end
end

T = Trailblazer::Activity::Testing

