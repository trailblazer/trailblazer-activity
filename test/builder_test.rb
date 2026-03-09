require "test_helper"

class PipelineBuilderTest < Minitest::Spec
  let(:exec_context_for_d) do
    Class.new do
      def self.d(ctx, lib_ctx, circuit_options, signal)
        ctx[:seq] << :d

        return ctx, lib_ctx, Trailblazer::Activity::Right
      end
    end
  end

  let(:exec_context_for_a) do
    T.def_steps(:a)
  end

  it "provides defaulting" do
    my_steps = T.def_steps(:b, :c)
    my_tasks = T.def_tasks(:d)

    my_node_with_circuit_interface = Class.new do
      def self.call(ctx, lib_ctx, signal, **circuit_options)
        ctx[:seq] << :e

        return ctx, lib_ctx, signal
      end
    end

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

      # task interface with defaulting, lib task with signal # FIXME.
      [:d, :d],

      # {node: Node.new} allows to bypass all defaulting and Node building.
      [:e, node: my_node_with_circuit_interface],
    )

    _, lib_ctx = assert_run circuit, terminus: Trailblazer::Activity::Right, # last signal is from {:d}.
      seq: [:a, :b, :c, :d, :e],
      exec_context: exec_context_for_d

    assert_equal lib_ctx, {exec_context: exec_context_for_d, :value=>true}
  end

  # it "accepts kwargs as circuit_options defaults" do
  #   circuit = Trailblazer::Activity::Circuit::Builder.Pipeline(

  #     # we can manually override the {circuit_options}:
  #     [:a, :a, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: exec_context_for_a}],

  #     # or use the pipe-wide default, see two lines below.
  #     [:d, :d],
  #     exec_context: exec_context_for_d
  #   )

  #   assert_run circuit, seq: [:a, :d], terminus: Trailblazer::Activity::Right # signal from {:a}.
  # end
end

class CircuitBuilderTest < Minitest::Spec
  it "what" do
    my_tasks = T.def_tasks(:c, :d)

    c_circuit, termini = Trailblazer::Activity::Circuit::Builder.Circuit(
      [[:c, my_tasks.method(:c), Trailblazer::Activity::Task::Invoker::LibInterface, {}], {Trailblazer::Activity::Right => :d, Trailblazer::Activity::Left => :failure}],
      [[:d, my_tasks.method(:d), Trailblazer::Activity::Task::Invoker::LibInterface, {}], {Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure}],
      [[:failure, node: failure = Trailblazer::Activity::Terminus::Failure.new(semantic: :failure)]],
      [[:success, node: success = Trailblazer::Activity::Terminus::Success.new(semantic: :success)]],

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
