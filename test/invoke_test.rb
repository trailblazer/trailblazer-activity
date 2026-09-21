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
    # wtf? can inject its extensions here, but no "global" canonical behavior.
    lib_ctx, flow_options, signal = Trailblazer::Activity::Invoke.(
      my_circuit,
      {target_ctx: {seq: []}},
      # extensions: [], id: :Create
      compiler: my_canonical_compiler,
    )

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal lib_ctx[:target_ctx][:seq], [:a]
  end
end
