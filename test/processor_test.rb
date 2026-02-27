require "test_helper"


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
      [:my_input, :my_input, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, {exec_context: my_exec_context}],
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

  it "un-scoped node processor" do
    process_node_called_from_process_task = _A::Circuit::Node::Processor.new # scope lib_ctx, call interface.

    node = [:my_input, :my_input, process_node_called_from_process_task, _A::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, {}] # it doesn't make sense to use an un-scoped node processor while passing lib_ctx options?

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

  it "what" do




  # scoping
    # process_node_called_from_process_task = _A::Circuit::Node::Processor::Scope.new([:value]) # scope lib_ctx, call interface.

    node = [:my_input, :my_input,
      _A::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, # how to run the actual task with the correct interface
      {exec_context: my_exec_context}, # how to change lib_ctx, starting from Node::Processor::Scoped
      # this used to sit in Circuit::Processor::Scoping
      _A::Circuit::Node::Processor::Scoped, # how to invoke the logic for this node?
      {copy_to_outer_ctx: [:value]} # FIXME: can we extend this at runtime? e.g. tracing needs :stack # options for
    ]

    result = _A::Circuit::Processor.process_node(node, {}, {exec_context: "outer"}, nil)

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

  it "is possible to implement wrap_runtime easily" do

  end

  it "is possible to re-set the original operation instance, if stored somewhere" do

  end

  it "is possible to change a start_task" do

  end
end
