require "test_helper"

class TestingTest < Minitest::Spec
  extend T.def_steps(:model)

  klass = Class.new do
    def self.persist
    end
  end

  it "what" do
    assert_equal T.render_task(TestingTest.method(:model)), %{#<Method: TestingTest.model>}
    assert_equal T.render_task(:model), %{model}
    assert_equal T.render_task(klass.method(:persist)), %{#<Method: #<Class:0x>.persist>}
  end



  it "#assert_call" do
    implemeting = T.def_tasks(:b, :c)

    activity = flat_activity(implementing: implementing)

    #@ {:seq} specifies expected `ctx[:seq]`.
    assert_call activity, seq: "[:b, :c]"
    #@ allows {:terminus}
    assert_call activity, seq: "[:b]", terminus: :failure, b: Trailblazer::Activity::Left

    # assert_raises do

    #   assert_call activity, seq: "[:b]", terminus: :not_right, b: Trailblazer::Activity::Left
    # end
  end

  it "what" do
    implementing = Module.new do
      extend T.def_tasks(:c)

      # b step adding additional ctx variables.
      def self.b((ctx, flow_options), **)
        ctx[:from_b] = "hello, from b!"
        return Trailblazer::Activity::Right, [ctx, flow_options]
      end
    end

    activity = flat_activity(implementing: implementing)

    #@ we can provide additional {:expected_ctx_variables}.
    assert_call activity, seq: "[:c]", expected_ctx_variables: {from_b: "hello, from b!"}
  end
end
