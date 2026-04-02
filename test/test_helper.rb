require "trailblazer/activity"
require "trailblazer/core"
require "minitest/autorun"

Minitest::Spec.class_eval do
  include Trailblazer::Core::Utils::AssertRun
  include Trailblazer::Core::Utils::AssertEqual
  T = Trailblazer::Core
end
