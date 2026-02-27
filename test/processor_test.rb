require "test_helper"

      class MyProcessForNode
      def call(node, ctx, lib_ctx, signal)
        id, task, me, interface_invoker, merge_to_lib_ctx = node

        lib_ctx = lib_ctx.merge(merge_to_lib_ctx) # DISCUSS: what merge strategy?

        interface_invoker.(task, ctx, lib_ctx, signal)
      end
    end

 class Process_Scope < Struct.new(:wrapped_noder, :copy_to_outer_ctx, :return_outer_signal)
      def call(node, ctx, outer_lib_ctx, signal)
        lib_ctx = Trailblazer::Context.new(outer_lib_ctx, {}) # TODO: allow setting options.

        ctx, lib_ctx, signal = wrapped_noder.(node, ctx, lib_ctx, signal) # super

        lib_ctx, signal = unscope(lib_ctx, outer_lib_ctx, signal)

        return ctx, lib_ctx, signal
      end

      # @private
      def unscope(lib_ctx, outer_ctx, signal)
        # outer_ctx, mutable = lib_ctx.decompose
        _FIXME_outer_ctx, mutable = lib_ctx.decompose

            copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
              # DISCUSS: is merge! and slice faster? no it's not.
              outer_ctx[key] = mutable[key] # if the task didn't write anything, we need to ask to big scoped ctx.
            end

              lib_ctx = outer_ctx
            # puts "@@@@@ ++++ #{id} #{copy_to_outer_ctx.inspect} #{mutable}"

            # public_variables = mutable.slice(*copy_to_outer_ctx) # it only makes sense to publish variables if they're "new".
            # lib_ctx = outer_ctx.merge(public_variables)
            # puts "finished processing Scoped.call"
            # puts "   #{lib_ctx.to_h}"



            # discard the returned signal from this circuit.
            if return_outer_signal
              signal = outer_signal
            end

        return lib_ctx, signal
      end
    end

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

  it "what" do


    process_node_called_from_process_task = MyProcessForNode.new # scope lib_ctx, call interface.

    node = [:my_input, :my_input, process_node_called_from_process_task, _A::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, {exec_context: my_exec_context}]

    result = _A::Circuit::Processor.process_node(node, {}, {exec_context: "outer"}, nil)

    assert_equal result,
      [
        {},
        {
          exec_context: my_exec_context, # without scoping, we bleed the "new" exec_context into the next step.
          value: :my_exec_context,
          bogus: true,
        },
        nil
      ]

  # scoping
    process_node_called_from_process_task = Process_Scope.new(MyProcessForNode.new, [:value]) # scope lib_ctx, call interface.

    node = [:my_input, :my_input, process_node_called_from_process_task, _A::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, {exec_context: my_exec_context}]

    result = _A::Circuit::Processor.process_node(node, {}, {exec_context: "outer"}, nil)

    assert_equal result,
      [
        {},
        {
          exec_context: "outer", #
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
