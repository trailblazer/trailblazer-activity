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

# Helpers to quickly create steps and tasks.
module T
  # Creates a module with one step method for each name.
  #
  # @example
  #   extend T.def_steps(:create, :save)
  def self.def_steps(*names)
    Module.new do
      names.each do |name|
        define_method(name) do | ctx, ** |
          ctx[:seq] << name
        end
      end
    end
  end

  # Creates a method instance with a task interface.
  #
  # @example
  #   task task: T.def_task(:create)
  def self.def_task(name)
    Module.new do
      define_singleton_method(name) do | (ctx, flow_options), ** |
        ctx[:seq] << name
        return Trailblazer::Activity::Right, [ctx, flow_options]
      end
    end.method(name)
  end
end
