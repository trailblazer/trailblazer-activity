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

  def Pipeline(*args)
    Trailblazer::Activity::Circuit::Builder.Pipeline(*args)
  end
end


# TODO: Context#freeze
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

    def self.scope_FIXME(outer_ctx, whitelisted_variables, mutable)
      new_ctx = outer_ctx

      if whitelisted_variables
        new_ctx = whitelisted_variables.collect { |key| [key, outer_ctx[key]] }.to_h
      end

      Trailblazer::Context.new(new_ctx, mutable.dup) # FIXME: add tests where we make sure we're dupping here, otherwise it starts bleeding!
    end

    def self.unscope_FIXME!(outer_ctx, ctx, copy_to_outer_ctx)
      _FIXME_outer_ctx, mutable = ctx.decompose

                  copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
                    # DISCUSS: is merge! and slice faster? no it's not.
                    # outer_ctx[key] = mutable[key] # if the task didn't write anything, we need to ask to big scoped ctx.
                    outer_ctx[key] = ctx[key] # if the task didn't write anything, we need to ask to big scoped ctx.
                  end

                  # raise "some pipes don't update :stack, that's why it is nil in mutable[:stack]"

      outer_ctx
    end
  end

  def self.Context(shadowed)
    Context.new(shadowed, {})
  end


  class MyContext
    def self.scope_FIXME(outer_ctx, whitelisted_variables, variables_to_merge)
      new_ctx =
        if whitelisted_variables
          outer_ctx.slice(*whitelisted_variables) # NOTE: feel free to improve runtime performance here, see benchmark # FIXME: insert link
        else
          outer_ctx
        end

      new_ctx.merge(variables_to_merge)
    end

    def self.unscope_FIXME!(outer_ctx, ctx, copy_to_outer_ctx)
      new_variables = ctx.slice(*copy_to_outer_ctx)

      outer_ctx.merge(new_variables)
    end
  end

  class MyContext_No_Slice
    def self.scope_FIXME(outer_ctx, whitelisted_variables, variables_to_merge)
      new_ctx =
        if whitelisted_variables
          whitelisted_variables.collect do |k|
            [k, outer_ctx[k]]
          end.to_h
          # outer_ctx.slice(*whitelisted_variables) # NOTE: feel free to improve runtime performance here, see benchmark # FIXME: insert link
        else
          outer_ctx
        end

      new_ctx.merge(variables_to_merge)
    end

    def self.unscope_FIXME!(outer_ctx, ctx, copy_to_outer_ctx)
      # new_variables = ctx.slice(*copy_to_outer_ctx)
      new_variables = copy_to_outer_ctx.collect do |k|
        [k, ctx[k]]
      end.to_h

      outer_ctx.merge(new_variables)
    end
  end
end
