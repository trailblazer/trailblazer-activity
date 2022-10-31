require "test_helper"

class TaskBuilderTest < Minitest::Spec
  describe "#inspect" do
    it { assert_equal Activity::TaskBuilder.Binary(:imaproc).inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=imaproc>} }

    it "AssignVariable" do
      decider = ->(ctx, mode:, **) { mode }

      circuit_task = Activity::Circuit::TaskAdapter.Binary(
        decider,
        adapter_class: Activity::Circuit::TaskAdapter::Step::AssignVariable,
        variable_name: :nested_activity
      )

      ctx = {mode: Object}
      signal, (ctx, flow_options) = circuit_task.([ctx, {}], **{exec_context: nil})

      assert_equal signal, Trailblazer::Activity::Right
      assert_equal ctx.inspect, %{{:mode=>Object, :nested_activity=>Object}}

    #@ returning false
      ctx = {mode: false}
      signal, (ctx, flow_options) = circuit_task.([ctx, {}], **{exec_context: nil})

      assert_equal signal, Trailblazer::Activity::Left
      assert_equal ctx.inspect, %{{:mode=>false, :nested_activity=>false}}
    end

  end
end
