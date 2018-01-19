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

  def assert_path(activity, content)
    process = activity.decompose[0]
    Cct(process).must_equal %{
#<Start:default/nil>#{content.chomp}
#<End:success/:success>
}
  end

  def SEQ(adds)
    tripletts = Trailblazer::Activity::Magnetic::Builder::Finalizer.adds_to_tripletts(adds)

    Seq(tripletts)
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

module T
  def self.def_task(name)
    Module.new do
      define_singleton_method(name) do | (ctx, flow_options), ** |
        ctx[:seq] << name
        return Trailblazer::Activity::Right, [ctx, flow_options]
      end
    end.method(name)
  end
end
