require "test_helper"

class PipelineBuilderTest < Minitest::Spec
  include T.def_steps(:a)

  it "provides defaulting" do
    my_steps = T.def_steps(:b, :c)
    my_tasks = T.def_tasks(:d)

    c_circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:c, my_steps.method(:c), Trailblazer::Activity::Task::Invoker::StepInterface]
    )

    circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(

      # instance method with step interface.
      [:a, :a, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: self}],

      # callable with step interface, we don't get defaulting here.
      [:b, my_steps.method(:b), Trailblazer::Activity::Task::Invoker::StepInterface],

      # defaulting for circuit_options for the nested pipe.
      [:c, c_circuit, Trailblazer::Activity::Circuit::Processor],

      # task interface with defaulting.
      [:d, my_tasks.method(:d)],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(circuit, {seq: []}, {}, {})

    assert_equal CU.inspect(ctx), %({:seq=>[:a, :b, :c, :d]})
    assert_equal CU.inspect(lib_ctx), %({:value=>true})
    assert_equal signal, Trailblazer::Activity::Right
  end

  it "allows configuring a signal different to {nil}" do
    my_tasks = T.def_tasks(:a, :b)

    circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:a, my_tasks.method(:a), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}, signal: Trailblazer::Activity::Left], # configure the returned signal.
      [:b, my_tasks.method(:b), Trailblazer::Activity::Task::Invoker::CircuitInterface],
    )

    # {:a} step returns Trailblazer::Activity::Left.
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(circuit, {seq: [], a: Trailblazer::Activity::Left}, {}, {})

    assert_equal CU.inspect(ctx), %({:seq=>[:a, :b], :a=>Trailblazer::Activity::Left})
    assert_equal CU.inspect(lib_ctx), %({})
    assert_equal signal, Trailblazer::Activity::Right # from {:b}
  end

  # TODO: :signal
end

class CircuitBuilderTest < Minitest::Spec
  it "what" do
    # my_steps = T.def_steps(:b, :c)
    my_tasks = T.def_tasks(:c)

    c_circuit = Trailblazer::Activity::Circuit::Builder.Circuit(
      [:c, my_tasks.method(:c), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}, Trailblazer::Activity::Right => :success_terminus, Trailblazer::Activity::Left => :failure_terminus],
      [:failure_terminus, failure = Trailblazer::Activity::Terminus::Success.new(semantic: :failure)],
      [:success_terminus, success = Trailblazer::Activity::Terminus::Success.new(semantic: :success)],

      termini: [:failure_terminus, :success_terminus],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(c_circuit, {seq: []}, {}, {})

    assert_equal CU.inspect(ctx), %({:seq=>[:c]})
    assert_equal CU.inspect(lib_ctx), %({})
    assert_equal signal, success

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(c_circuit, {seq: [], c: Trailblazer::Activity::Left}, {}, {})

    assert_equal CU.inspect(ctx), %({:seq=>[:c], :c=>Trailblazer::Activity::Left})
    assert_equal CU.inspect(lib_ctx), %({})
    assert_equal signal, failure
  end
end
