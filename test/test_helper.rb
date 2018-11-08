$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "pp"
require "trailblazer-activity"

require "minitest/autorun"

require "trailblazer/developer/render/circuit"

Minitest::Spec::Activity = Trailblazer::Activity

Minitest::Spec.class_eval do
  def Cct(*args)
    Trailblazer::Developer::Render::Circuit.(*args)
      .gsub(/\d\d+/, "")
  end

  def inspect_task_builder(task)
    proc = task.instance_variable_get(:@user_proc)
    match = proc.inspect.match(/(\w+)>$/)

    %{#<TaskBuilder{.#{match[1]}}>}
  end

  # builder for PlusPoles
  def plus_poles_for(mapping)
    ary = mapping.collect { |evt, semantic| [Trailblazer:: Activity::Output(evt, semantic), semantic ] }

    Trailblazer::Activity::Magnetic::PlusPoles.new.merge(::Hash[ary])
  end

  def assert_path(activity, content)
    Cct(activity).must_equal %{
#<Start/:default>#{content.chomp}
#<End/:success>
}
  end

  def SEQ(adds)
    tripletts = Trailblazer::Activity::Magnetic::Builder::Finalizer.adds_to_tripletts(adds)

    Trailblazer::Activity::Magnetic::Introspect.Seq(tripletts)
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

  # TODO: move to -magnetic
module Trailblazer::Activity::Magnetic
  module Introspect
    # def self.cct(builder)
    #   adds = builder.instance_variable_get(:@adds)
    #   circuit, _ = Builder::Finalizer.(adds)

    #   Cct(circuit)
    # end

    private

    def self.Seq(sequence)
      content =
        sequence.first.collect do |(magnetic_to, task, plus_poles)|
          pluses = plus_poles.collect { |plus_pole| PlusPole(plus_pole) }

%{#{magnetic_to.inspect} ==> #{Trailblazer::Developer::Render::Circuit.inspect_with_matcher(task)}
#{pluses.empty? ? " []" : pluses.join("\n")}}
        end.join("\n")

  "\n#{content}\n".gsub(/\d\d+/, "").gsub(/0x\w+/, "0x")
    end

    def self.PlusPole(plus_pole)
      signal = plus_pole.signal.to_s.sub("Trailblazer::Activity::", "")
      semantic = plus_pole.send(:output).semantic
      " (#{semantic})/#{signal} ==> #{plus_pole.color.inspect}"
    end
  end
end

require "trailblazer/activity/testing"
T = Trailblazer::Activity::Testing
