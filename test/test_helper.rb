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

# TODO: move me to core-utils. test me.
module AssertRun
  def assert_run(circuit, processor: Trailblazer::Activity::Circuit::Processor, exec_context: nil, terminus: nil, seq:, **ctx)
    circuit_options = exec_context ? {exec_context: exec_context} : {}

    ctx, lib_ctx, signal = processor.(circuit, ctx.merge(seq: []), {}, circuit_options, nil)

    assert_equal signal, terminus
    assert_equal ctx[:seq], seq # FIXME: test all ctx variables.

    return ctx, lib_ctx, signal
  end
end

Minitest::Spec.class_eval do
  require "trailblazer/core"
  CU = Trailblazer::Core::Utils

  include AssertRun

  let(:_A) { Trailblazer::Activity }
end




module Trailblazer
  class Context < Struct.new(:shadowed, :mutable)
    def []=(key, value)
      mutable[key] = value

      # @to_h[key] = value
    end

    def [](key)
      # raise
      mutable[key] || shadowed[key] # FIXME.
    end

    def merge(variables)
      # raise
      # puts variables.inspect
      Context.new(shadowed, mutable.merge(variables))
    end

    def decompose
      return shadowed, mutable
    end

    def to_h
      # return @to_h
      shadowed.to_h.merge(mutable) # DISCUSS: shadowed.to_h we only should do once, at instantiation!
    end

    def to_hash # implicit conversion to Hash.
      to_h
    end
  end

  def self.Context(shadowed)
    Context.new(shadowed, {})
  end
end
