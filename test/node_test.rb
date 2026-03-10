require "test_helper"

class NodeScopedTest < Minitest::Spec
  it "{#initialize} defaults" do
    # DISCUSS: we shouldn't create Node instances without a Builder.
    my_node = _A::Circuit::Node::Scoped[id: :"a", task: :a, interface: _A::Circuit::Processor]

    assert_equal my_node.to_h, {
      id: :"a",
      task: :a,
      interface: _A::Circuit::Processor,
      merge_to_lib_ctx: {},
      :copy_from_outer_ctx=>nil,
      :copy_to_outer_ctx=>[],
      :return_outer_signal=>false
    }
  end

  it "{#initialize} accepts explicit options" do
    # DISCUSS: we shouldn't create Node instances without a Builder.
    my_node = _A::Circuit::Node::Scoped[id: :"a", task: :a, interface: _A::Circuit::Processor, merge_to_lib_ctx: {exec_context: Object}, copy_from_outer_ctx: [:a], copy_to_outer_ctx: [:b], return_outer_signal: true]

    assert_equal my_node.to_h, {
      id: :"a",
      task: :a,
      interface: _A::Circuit::Processor,
      merge_to_lib_ctx: {exec_context: Object},
      :copy_from_outer_ctx=>[:a],
      :copy_to_outer_ctx=>[:b],
      :return_outer_signal=>true
    }
  end

  it "{#to_h}" do
    # this is currently tested implicitely above :D
  end
end

class TerminusNodeTest < Minitest::Spec
  it "Success#call" do
    success = Trailblazer::Activity::Terminus::Success[semantic: :success]

    result = success.({params: {}}, {exec_context: Object}, nil, current_task: Module)
    assert_equal result, [
      {params: {}},
      {exec_context: Object},
      success # signal is the terminus instance itself.
    ]
  end

  it "Failure#call" do
    failure = Trailblazer::Activity::Terminus::Failure[semantic: :pass_fast]

    result = failure.({params: {}}, {exec_context: Object}, nil, current_task: Module)
    assert_equal result, [
      {params: {}},
      {exec_context: Object},
      failure # signal is the terminus instance itself.
    ]
  end

  it "{#initialize} takes any kwargs" do
    success = Trailblazer::Activity::Terminus::Success[semantic: :success, copy_from_outer_ctx: []]

    assert_equal success.to_h, {semantic: :success}
  end
end

class NodeRunnerTest < Minitest::Spec
  it "{Runner.call}" do
    my_pipe = Pipeline(
      [:a, :a, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:b, :b, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:c, :c, _A::Task::Invoker::StepInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node::Scoped[id: :my_pipe_node, task: my_pipe, interface: _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner

    my_exec_context = T.def_steps(:a, :b, :c)

    ctx, lib_ctx, signal = runner.(my_pipe_node, {seq: []}, {exec_context: my_exec_context}, nil,
      runner: runner,
      context_implementation: Trailblazer::MyContext,
    )

    assert_equal ctx[:seq], [:a, :b, :c]
  end

  # TODO: this tests Processor.
  it "accepts {:start_node}" do
    my_pipe = Pipeline(
      [:a, :a, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:b, :b, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:c, :c, _A::Task::Invoker::StepInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node::Scoped[id: :my_pipe_node, task: my_pipe, interface: _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner

    my_exec_context = T.def_steps(:a, :b, :c)

    ctx, lib_ctx, signal = runner.(my_pipe_node, {seq: []}, {exec_context: my_exec_context}, nil, runner: runner,
      start_node: [:b, my_pipe.config[:b]],
      context_implementation: Trailblazer::MyContext,
    )

    assert_equal ctx[:seq], [:b, :c]
  end
end
