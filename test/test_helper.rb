$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer-activity"

require "minitest/autorun"


Minitest::Spec::Activity = Trailblazer::Activity

Minitest::Spec.class_eval do
  def Inspect(*args)
    Trailblazer::Activity::Inspect::Instance(*args)
  end

  extend Forwardable
  def_delegators Trailblazer::Activity::Introspect, :Seq, :Cct, :circuit_hash, :Ends, :Outputs
  def_delegators Trailblazer::Activity::Magnetic::Introspect, :Seq

  # builder for PlusPoles
  def plus_poles_for(mapping)
    ary = mapping.collect { |evt, semantic| [Trailblazer:: Activity::Output(evt, semantic), semantic ] }

    Trailblazer::Activity::Magnetic::DSL::PlusPoles.new.merge(::Hash[ary])
  end
end

Trailblazer::Activity.module_eval do
  def self.build(&block)
    Class.new(Trailblazer::Activity, &block)
  end
end

