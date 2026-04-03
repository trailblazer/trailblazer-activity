require_relative "test_helper"

class StepTest < Minitest::Spec
  Step = Trailblazer::Activity::Step

  let(:my_exec_context) { T.def_steps(:a) }

  it "uses flow_options[:application_ctx] as target_ctx and returns a binary signal" do
    my_node = Trailblazer::Activity::Step.build(:a)

    lib_ctx, flow_options, signal = assert_run my_node, node: true, seq: [:a],
      exec_context: my_exec_context,
      terminus: Trailblazer::Activity::Right

    lib_ctx, flow_options, signal = assert_run my_node, node: true, seq: [:a],
      exec_context: my_exec_context,
      flow_options: {application_ctx: {seq: [], a: false}},
      terminus: Trailblazer::Activity::Left
  end

  it "can invoke callables" do
    my_node = Trailblazer::Activity::Step.build(my_exec_context.method(:a))

    lib_ctx, flow_options, signal = assert_run my_node, node: true, seq: [:a],
      exec_context: my_exec_context,
      terminus: Trailblazer::Activity::Right

    lib_ctx, flow_options, signal = assert_run my_node, node: true, seq: [:a],
      exec_context: my_exec_context,
      flow_options: {application_ctx: {seq: [], a: false}},
      terminus: Trailblazer::Activity::Left
  end

  it "{binary: false} only sets {:value} on internal {lib_ctx}" do
    my_exec_context = Class.new do
      def a(ctx, seq:, **)
        seq << :a

        {my_value: Hash}
      end
    end.new

    my_node = Trailblazer::Activity::Step.build(:a, binary: false, copy_to_outer_ctx: [:value])

    lib_ctx, flow_options, signal = assert_run my_node, node: true, seq: [:a],
      exec_context: my_exec_context,
      terminus: nil

    assert_equal lib_ctx, {exec_context: my_exec_context, value: {my_value: Hash}}
  end

  it "doesn't rely on {application_ctx} mutability and writes the {target_ctx} back to {flow_options}" do

  end
end


