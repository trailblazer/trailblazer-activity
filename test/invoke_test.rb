require "test_helper"

class InvokeTest < Minitest::Spec
  it "what" do
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:a, T.def_tasks(:a).method(:a)],
    )

    assert_run my_circuit, seq: [:a], terminus: Trailblazer::Activity::Right

    Trailblazer::Activity::Invoke.(my_circuit, {target_ctx: {seq: []}}, extensions: [], id: :Create)

    # we want
    # 1. call Circuit/node without having to remember all the flow_options, canonical node etc. use in #assert_run
    # 2. #wtf? can "inject" its pieces into the canonical invoke that might have other parts
    # 3. we can run Wtf.() without the canonical invoke.
    # 4.
  end
end
