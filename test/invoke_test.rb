require "test_helper"

class InvokeTest < Minitest::Spec
  let(:my_circuit) do
    Trailblazer::Circuit::Builder.Pipeline(
      [:a, T.def_tasks(:a).method(:a)],
    )
  end

  it "the default compiler only compiles a {:wrap_runtime} (TODO: test that we don't use it if no extensions are passed?)" do
    assert_run my_circuit, seq: [:a], terminus: Trailblazer::Activity::Right

    # wtf? can inject its extensions here, but no "global" canonical behavior.
    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(my_circuit, {target_ctx: {seq: []}}, extensions: [], id: :Create)

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal lib_ctx[:target_ctx][:seq], [:a]

    # we want
    # 1. call Circuit/node without having to remember all the flow_options, canonical node etc. use in #assert_run
    # 2. #wtf? can "inject" its pieces into the canonical invoke that might have other parts
    # 3. we can run Wtf.() without the canonical invoke.
    # 4.
  end

  it "we can use a canonical pipe that might have preconfigured steps (in a more or less global way)" do
    my_create_lib_ctx = ->(lib_ctx, flow_options, circuit_options, **) do
      lib_ctx = lib_ctx.merge(target_ctx: {seq: [1, 2, 3]})

      return lib_ctx, flow_options, circuit_options
    end

    my_create_node = ->(lib_ctx, flow_options, circuit_options, **) do
      return lib_ctx, flow_options, circuit_options.merge(node: Trailblazer::Circuit::Node[circuit_options.fetch(:circuit), Trailblazer::Circuit::Processor])
    end

    my_canonical_compiler = Trailblazer::Circuit::Builder.Pipeline(
      [:create_lib_ctx, my_create_lib_ctx, Trailblazer::Circuit::Task::Adapter::LibInterface], # TODO: introduce Invoke::Interface
      [:create_node, my_create_node, Trailblazer::Circuit::Task::Adapter::LibInterface] # TODO: introduce Invoke::Interface
    )

    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(
      my_circuit,
      {},
      # extensions: [], id: :Create
      compiler: my_canonical_compiler,
      wrap_runtime: {}
    )

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal lib_ctx[:target_ctx][:seq], [1, 2, 3, :a]
  end
end
