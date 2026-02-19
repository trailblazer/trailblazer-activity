# require "pp"
require "trailblazer/activity"
require "minitest/autorun"
# require "trailblazer/developer"

require "amazing_print"
AmazingPrint.defaults = {
  :indent => -2,
  :color => {
    :hash  => :red,
    :class => :gray,
    :array => :blue,
  }
}

Minitest::Spec.class_eval do
  def assert_equal(asserted, expected, *args)
    super(expected, asserted, *args)
  end

  require "trailblazer/core"
  include Trailblazer::Core::Utils::Assertions
  T = Trailblazer::Core

  module Minitest::Spec::Implementing
    extend T.def_tasks(:a, :b, :c, :d, :f, :g)

    Start = Trailblazer::Activity::Start.new(semantic: :default)
    Failure = Trailblazer::Activity::End(:failure)
    Success = Trailblazer::Activity::End(:success)
  end
end

Minitest::Spec.class_eval do
  require "trailblazer/core"
  CU = Trailblazer::Core::Utils
end
