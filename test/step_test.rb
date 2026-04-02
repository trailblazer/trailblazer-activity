require_relative "test_helper"

class StepTest < Minitest::Spec
  Step = Trailblazer::Activity::Step

  it "doesn't rely on {application_ctx} mutability and writes the {target_ctx} back to {flow_options}" do
    my_exec_context = T.def_steps(:a)

    my_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:set_target_ctx, Step.method(:set_target_ctx)], # DISCUSS: the target_ctx related steps might be changed. They're currently the cleanest way to "configure" {invoke_provider}.
      [:invoke_provider, :a, Trailblazer::Circuit::Task::Adapter::StepInterface::InstanceMethod],
      [:unset_target_ctx, Step.method(:unset_target_ctx)], # write the mutated target_ctx back to where it came from originally.
      [:compute_binary_signal, Step::ComputeBinarySignal],
    )

    lib_ctx, flow_options, signal = assert_run my_pipe, seq: [:a],
      exec_context: my_exec_context,
      terminus: Trailblazer::Activity::Right
  end
end


