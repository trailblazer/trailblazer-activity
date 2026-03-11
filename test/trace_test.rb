require "test_helper"

# I play a bit with the ctx vs lib_ctx idea here, first.
class TracePrototypeTest < Minitest::Spec
  it "what" do
    Circuit = Trailblazer::Activity::Circuit
    Builder = Trailblazer::Activity::Circuit::Builder
    Task = Trailblazer::Activity::Task

    Model = Struct.new(:id)

    my_step_interface_exec_context = Class.new do
      def my_model_step(ctx, params:, **)
        ctx[:model] = Model.new(params[:id])
      end
    end.new

    # repeating Builder::Step::InstanceMethod here:
    # here, we do not want :task from tW, and we do not want :stack around!
    model_pipe = Builder.Pipeline(
      # this step changes {application_ctx} and adds lib_ctx[:value]
      [:invoke_instance_method, :my_model_step, Task::Invoker::StepInterface::InstanceMethod, {exec_context: my_step_interface_exec_context}, Trailblazer::Activity::Circuit::Node::Scoped, copy_to_outer_ctx: [:value]], # FIXME: implement that we reuse and "older" exec_context. for now, i ignore that for designing.

      [:compute_binary_signal, Circuit::Step::ComputeBinarySignal, Task::Invoker::LibInterface],
    )

    pp model_pipe

    call_model_node = Circuit::Node::Scoped[id: :my_model, task: model_pipe, interface: Circuit::Processor,
      # copy_to_outer_ctx: [:original_application_ctx]
    ]

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Node::Runner.(
      call_model_node,
      {params: {id: 1}},
      {},
      nil,
      runner:  _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext,
    )

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal ctx, {params: {id: 1}, model: Model.new(1)}
  end
end
