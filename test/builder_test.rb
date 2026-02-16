require "test_helper"

class PipelineBuilderTest < Minitest::Spec
  include T.def_steps(:a)

  it "provides defaulting" do
    my_module = T.def_steps(:b, :c)
    my_tasks = T.def_tasks(:d)

    c_circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:c, my_module.method(:c), Trailblazer::Activity::Task::Invoker::StepInterface]
    )

    circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(

      # instance method with step interface.
      [:a, :a, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: self}],

      # callable with step interface, we don't get defaulting here.
      [:b, my_module.method(:b), Trailblazer::Activity::Task::Invoker::StepInterface],

      # defaulting for circuit_options for the nested pipe.
      [:c, c_circuit, Trailblazer::Activity::Circuit::Processor],

      # task interface with defaulting.
      [:d, my_tasks.method(:d)],
    )

    ctx, signal = Trailblazer::Activity::Circuit::Processor.(circuit, {application_ctx: {seq: []}})

    assert_equal CU.inspect(ctx), %({:application_ctx=>{:seq=>[:a, :b, :c, :d]}, :value=>true})
    assert_equal signal, Trailblazer::Activity::Right
  end

  # TODO: :signal
end
