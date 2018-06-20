require "simplecov"
SimpleCov.start do
  add_group "Trailblazer-Activity", "lib"
  add_group "Tests", "test"
end

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

    Trailblazer::Activity::Magnetic::PlusPoles.new.merge(::Hash[ary])
  end

  def assert_path(activity, content)
    circuit = activity.to_h[:circuit]
    Cct(circuit).must_equal %{
#<Start/:default>#{content.chomp}
#<End/:success>
}
  end

  def SEQ(adds)
    tripletts = Trailblazer::Activity::Magnetic::Builder::Finalizer.adds_to_tripletts(adds)

    Seq(tripletts)
  end


  Memo = Struct.new(:id, :body) do
    def self.find(id)
      return new(id, "Yo!") if id
      nil
    end
  end
end

Trailblazer::Activity.module_eval do
  def self.build(&block)
    Module.new do
      extend Trailblazer::Activity[]
      yield
    end
  end
end

require "trailblazer/activity/testing"
T = Trailblazer::Activity::Testing
