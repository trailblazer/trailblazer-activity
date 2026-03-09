require "test_helper"
require "ruby-prof"

class Processor_Scoped_Test < Minitest::Spec
  it "what" do
    my_exec_context = Class.new do
      def my_input(ctx, lib_ctx, signal, **)
        lib_ctx[:value] = 1
        lib_ctx[:bogus] = true

        return ctx, lib_ctx, signal
      end
    end.new

    pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:my_input, :my_input, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {exec_context: my_exec_context}],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(
      pipe,
      {id: 1},
      {exec_context: self}, # outer lib_ctx.
      nil,

      **{exec_context: my_exec_context, copy_to_outer_ctx: [:value]}, # this is merged, where?
    )

    assert_equal lib_ctx.to_h, {exec_context: self, value: 1}
  end
end


class InvokerTest < Minitest::Spec
  let(:my_exec_context) do
    Class.new do
      def my_input(ctx, lib_ctx, signal, **)
        lib_ctx[:value] = :my_exec_context
        lib_ctx[:bogus] = true

        return ctx, lib_ctx, signal
      end
    end.new
  end

  def my_input(ctx, lib_ctx, signal, **)
    lib_ctx[:value] = :self
    lib_ctx[:bogus] = true

    return ctx, lib_ctx, signal
  end

  class MyExecContext
    def self.my_capture_lib_ctx(ctx, lib_ctx, signal, **kwargs)
      ctx[:captured] = [
        CU.inspect(lib_ctx),
        kwargs.keys
      ]

      return ctx, lib_ctx, signal
    end
  end

  it "scoping: without In(), we get a Context wrapping another Context" do
    outer_lib_ctx = Trailblazer::Context(value: 1, exec_context: MyExecContext)
    outer_lib_ctx[:sun] = true

    node = [:my_capture_lib_ctx, :my_capture_lib_ctx, _A::Task::Invoker::LibInterface::InstanceMethod, {}, _A::Circuit::Node::Processor::Scoped, {}]

    ctx, lib_ctx, signal = nil
    result = RubyProf::Profile.profile do
      ctx, lib_ctx, signal = _A::Circuit::Node::Runner.(node, {}, outer_lib_ctx, nil)
    end
    printer = RubyProf::FlatPrinter.new(result)
    printer.print(STDOUT)
    #  6.89      0.000     0.000     0.000     0.000        2  *Trailblazer::Context#to_h
    #  2.93      0.000     0.000     0.000     0.000        1   Trailblazer::Context#decompose
    #  3.10      0.000     0.000     0.000     0.000        5   #<Class:0x000078f6c38cb2d8>#shadowed
    #  2.78      0.000     0.000     0.000     0.000        5   #<Class:0x000078f6c38cb2d8>#mutable


    assert_equal ctx,
      {
        captured: [
          %(#<struct Trailblazer::Context shadowed=#<struct Trailblazer::Context shadowed={:value=>1, :exec_context=>InvokerTest::MyExecContext}, mutable={:sun=>true}>, mutable={}>),
          [:value, :exec_context, :sun]
        ],
      }
    # the original Context instance from above.
    assert_equal CU.inspect(lib_ctx), %(#<struct Trailblazer::Context shadowed={:value=>1, :exec_context=>InvokerTest::MyExecContext}, mutable={:sun=>true}>)
    assert_nil signal
  end

  it "scoping: with {:copy_from_outer_ctx}, we get one Context without wrapping inside" do
    outer_lib_ctx = Trailblazer::Context(value: 1, exec_context: MyExecContext)
    outer_lib_ctx[:sun] = true

    node = [:my_capture_lib_ctx, :my_capture_lib_ctx, _A::Task::Invoker::LibInterface::InstanceMethod, {}, _A::Circuit::Node::Processor::Scoped, {copy_from_outer_ctx: [:sun, :exec_context]}]

    ctx, lib_ctx, signal = nil
    # result = RubyProf::Profile.profile do
      ctx, lib_ctx, signal = _A::Circuit::Node::Runner.(node, {}, outer_lib_ctx, nil)
    # end
    # printer = RubyProf::FlatPrinter.new(result)
    # printer.print(STDOUT)
    #  6.89      0.000     0.000     0.000     0.000        2  *Trailblazer::Context#to_h
    #  2.93      0.000     0.000     0.000     0.000        1   Trailblazer::Context#decompose
    #  3.10      0.000     0.000     0.000     0.000        5   #<Class:0x000078f6c38cb2d8>#shadowed
    #  2.78      0.000     0.000     0.000     0.000        5   #<Class:0x000078f6c38cb2d8>#mutable

    assert_equal ctx,
      {
        captured: [
          # %(#<struct Trailblazer::Context shadowed=#<struct Trailblazer::Context shadowed={:value=>1, :exec_context=>InvokerTest::MyExecContext}, mutable={:sun=>true}>, mutable={}>),
          %(#<struct Trailblazer::Context shadowed={:sun=>true, :exec_context=>InvokerTest::MyExecContext}, mutable={}>),
          [:sun, :exec_context]
        ],
      }
    # the original Context instance from above.
    assert_equal CU.inspect(lib_ctx), %(#<struct Trailblazer::Context shadowed={:value=>1, :exec_context=>InvokerTest::MyExecContext}, mutable={:sun=>true}>)
    assert_nil signal
  end

  # FIXME: test properly
  it "{Processor#process_node}" do
    node = [:my_input, :my_input, _A::Task::Invoker::LibInterface::InstanceMethod, {}, _A::Circuit::Node::Processor, {}] # it doesn't make sense to use an un-scoped node processor while passing lib_ctx options?

    result = _A::Circuit::Processor.process_node(node, {}, {exec_context: self}, nil)

    assert_equal result,
      [
        {},
        {
          exec_context: self, # without scoping, we bleed the "new" exec_context into the next step.
          value: :self,
          bogus: true,
        },
        nil
      ]
  end

  let(:node_producing_value) do
    node = [:my_input, :my_input,
      _A::Task::Invoker::LibInterface::InstanceMethod, # how to run the actual task with the correct interface
      {exec_context: my_exec_context}, # how to change lib_ctx, starting from Node::Processor::Scoped
      # this used to sit in Circuit::Processor::Scoping
      _A::Circuit::Node::Processor::Scoped, # how to invoke the logic for this node?
      {copy_to_outer_ctx: [:value]} # FIXME: can we extend this at runtime? e.g. tracing needs :stack # options for
    ]
  end

  it "what" do
  # scoping
    result = _A::Circuit::Processor.process_node(node_producing_value, {}, {exec_context: "outer"}, nil)

    assert_equal result,
      [
        {},
        {
          exec_context: "outer", # original value.
          value: :my_exec_context # context change!
          # and a clean {lib_ctx}.
        },
        nil
      ]
  end

  it "#process_node with a real Circuit, we can not pass options_for_node_runner, but assign them in the node" do
    pipeline = Trailblazer::Activity::Circuit::Builder.Pipeline(
      node_producing_value
    )

    # pp pipeline
    circuit_node = [
      :my_task_wrap,
      pipeline,
      _A::Circuit::Processor,       {},
      _A::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:value, :bogus]}
    ]

    result = _A::Circuit::Processor.process_node(circuit_node, {}, {exec_context: "outer"}, nil)

    assert_equal result,
      [
        {},
        {
          exec_context: "outer", # original value.
          value: :my_exec_context, # context change!
          # and a clean {lib_ctx}.
          bogus: nil,
        },
        nil
      ]
  end


  it "is possible to implement wrap_runtime easily" do

  end

  it "is possible to re-set the original operation instance, if stored somewhere" do

  end

  it "{Runner.call}" do
    my_pipe = Pipeline(
      [:a, :a, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:b, :b, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:c, :c, _A::Task::Invoker::StepInterface::InstanceMethod],
    )

    my_pipe_node = [:my_pipe_node, my_pipe, _A::Circuit::Processor, {}, _A::Circuit::Node::Processor::Scoped, {}]
    runner = _A::Circuit::Node::Runner

    my_exec_context = T.def_steps(:a, :b, :c)

    ctx, lib_ctx, signal = runner.(my_pipe_node, {seq: []}, {exec_context: my_exec_context}, nil, runner: runner)

    assert_equal ctx[:seq], [:a, :b, :c]
  end

  # TODO: this tests Processor.
  it "accepts {:start_node}" do
    my_pipe = Pipeline(
      [:a, :a, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:b, :b, _A::Task::Invoker::StepInterface::InstanceMethod],
      [:c, :c, _A::Task::Invoker::StepInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node::Scoped[:my_pipe_node, my_pipe, _A::Circuit::Processor, {}, {}]
    runner = _A::Circuit::Node::Runner

    my_exec_context = T.def_steps(:a, :b, :c)

    ctx, lib_ctx, signal = runner.(my_pipe_node, {seq: []}, {exec_context: my_exec_context}, nil, runner: runner,
      start_node: [:b, my_pipe.config[:b]],
      context_implementation: Trailblazer::MyContext
    )

    assert_equal ctx[:seq], [:b, :c]
  end
end
