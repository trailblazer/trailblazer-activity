require "test_helper"

class PipelineBuilderTest < Minitest::Spec
  it "provides defaulting" do
    my_steps = T.def_steps(:b, :c)
    my_tasks = T.def_tasks(:d)
    exec_context_for_a = T.def_steps(:a)

    c_circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:c, my_steps.method(:c), Trailblazer::Activity::Task::Invoker::StepInterface]
    )

    circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(
      # instance method with step interface.
      [:a, :a, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: exec_context_for_a}],

      # callable with step interface, we don't get defaulting here.
      [:b, my_steps.method(:b), Trailblazer::Activity::Task::Invoker::StepInterface],

      # defaulting for circuit_options for the nested pipe.
      [:c, c_circuit, Trailblazer::Activity::Circuit::Processor],

      # task interface with defaulting.
      [:d, my_tasks.method(:d)],
    )


    _, lib_ctx = assert_run circuit, terminus: Trailblazer::Activity::Right, # last signal is from {:d}.
      seq: [:a, :b, :c, :d]

    assert_equal CU.inspect(lib_ctx), %({:value=>true})
  end
end

class CircuitBuilderTest < Minitest::Spec
  it "what" do
    # my_steps = T.def_steps(:b, :c)
    my_tasks = T.def_tasks(:c, :d)

    c_circuit, termini = Trailblazer::Activity::Circuit::Builder.Circuit(
      [:c, my_tasks.method(:c), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}, Trailblazer::Activity::Right => :d, Trailblazer::Activity::Left => :failure],
      [:d, my_tasks.method(:d), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}, Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure],
      [:failure, failure = Trailblazer::Activity::Terminus::Failure.new(semantic: :failure)],
      [:success, success = Trailblazer::Activity::Terminus::Success.new(semantic: :success)],

      termini: [:failure, :success],
    )

    assert_equal termini, {success: success, failure: failure}

    ctx, lib_ctx = assert_run c_circuit, terminus: termini[:success], seq: [:c, :d]
    assert_equal lib_ctx, {}

    ctx, lib_ctx = assert_run c_circuit, terminus: termini[:failure], seq: [:c], c: Trailblazer::Activity::Left
    assert_equal lib_ctx, {}


    ctx, lib_ctx = assert_run c_circuit, terminus: termini[:failure], seq: [:c, :d], d: Trailblazer::Activity::Left
    assert_equal lib_ctx, {}
  end
end
