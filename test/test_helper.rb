$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "trailblazer-activity"

require "minitest/autorun"

require "trailblazer/circuit/testing"

require "pp"

Inspect = Trailblazer::Activity::Inspect

Minitest::Spec::Circuit  = Trailblazer::Circuit
Minitest::Spec::Activity = Trailblazer::Activity

Minitest::Spec.class_eval do
  def Inspect(*args)
    Trailblazer::Activity::Inspect::Instance(*args)
  end
end
