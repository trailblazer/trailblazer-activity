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

  it "callable providers don't get Scoped" do
    skip "we currently set lib_ctx[:target_ctx] and hence need scoping :)"
    my_node = Trailblazer::Activity::Step.build(my_exec_context.method(:a))

    lib_ctx, flow_options, signal = assert_run my_node, node: true, seq: [:a],
      terminus: Trailblazer::Activity::Right

    assert_equal lib_ctx, {a: 1}
  end

  it "{binary: false} only returns value-on-signal" do
    my_exec_context = Class.new do
      def a(ctx, seq:, **)
        seq << :a

        {my_value: Hash} # this will be the returned "signal" (value-on-signal).
      end
    end.new

    my_node = Trailblazer::Activity::Step.build(:a, binary: false)

    lib_ctx, flow_options, signal = assert_run my_node, node: true, seq: [:a],
      exec_context: my_exec_context,
      terminus: {my_value: Hash}

    assert_equal lib_ctx, {exec_context: my_exec_context}
  end

  it "we can return any signal. currently, the {is_signal?} step is added per default" do
    my_signal = Class.new(Trailblazer::Activity::Signal)

    my_provider = ->(ctx, signals:, **) do
      signals[1]
    end

    my_node = Trailblazer::Activity::Step.build(my_provider, binary: true)

    lib_ctx, flow_options, signal = assert_run my_node, node: true,
      terminus: my_signal,
      seq: nil,
      flow_options: {application_ctx: {signals: [0, my_signal, 2]}}
  end

  it "doesn't rely on {application_ctx} mutability and writes the {target_ctx} back to {flow_options}" do

  end
end


