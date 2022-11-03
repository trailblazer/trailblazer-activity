require "test_helper"

class TaskAdapterTest < Minitest::Spec
  it "Circuit::TaskAdapter" do
    class Operation
      def process_type(ctx, model:, **)
        return if model.nil?

        ctx[:type] = model.class
      end
    end


    # steps receive ctx and kwargs
    # steps can write to something
    # steps return an outcome "boolean"/return value
    step = ->(ctx, model:, **) do
      return if model.nil?

      ctx[:type] = model.class
    end

    flow_options    = {}
    circuit_options = {}

    ctx             = {model: nil}

  # execute step in a circuit-interface environment
    circuit_step = Activity::Circuit::Step(step) # circuit step receives circuit-interface but returns only value
    return_value, ctx = circuit_step.([ctx, flow_options], **circuit_options)

    assert_nil return_value
    assert_equal ctx.inspect, %{{:model=>nil}}


  #@ execute step-option in a circuit-interface environment
    circuit_step = Activity::Circuit.Step(step, option: true) # wrap step with Trailblazer::Option
    return_value, ctx = circuit_step.([ctx, flow_options], **circuit_options, exec_context: self)
    assert_nil return_value
    assert_equal ctx.inspect, %{{:model=>nil}}

    circuit_step = Activity::Circuit::Step(:process_type, option: true) # wrap step with Trailblazer::Option
    return_value, ctx = circuit_step.([ctx, flow_options], **circuit_options, exec_context: Operation.new)
    assert_nil return_value
    assert_equal ctx.inspect, %{{:model=>nil}}

  #@ circuit-interface Option-compatible Step that does a Binary signal decision
    step          = :process_type
    circuit_task  = Activity::Circuit::Task.for_step(step, option: true)

    ctx = {model: nil}
    signal, (ctx, flow_options) = circuit_task.([ctx, flow_options], **circuit_options, exec_context: Operation.new)

    assert_equal signal, Trailblazer::Activity::Left
    assert_equal ctx.inspect, %{{:model=>nil}}
    assert_equal flow_options.inspect, %{{}}

    ctx = {model: Object}
    signal, (ctx, flow_options) = circuit_task.([ctx, flow_options], **circuit_options, exec_context: Operation.new)

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal ctx.inspect, %{{:model=>Object, :type=>Class}}
    assert_equal flow_options.inspect, %{{}}

#@ pipeline-interface

    step = :process_type
    args = [1,2]

    pipeline_step = Activity::Circuit::Task.for_step(step, option: true) # Task receives circuit-interface but it's compatible with Pipeline interface
    wrap_ctx, args = pipeline_step.([ctx, args], exec_context: Operation.new) # that's how pipeline tasks are called in {TaskWrap::Pipeline}.

    assert_equal wrap_ctx.inspect, %{{}}
    assert_equal args, [1,2]



raise







    Activity::Circuit::TaskAdapter.Binary
    Activity::Circuit::Task.for_step(circuit_step) # compute the return value (and also return the mutated object)

    # Circuit consists of {Circuit::Task} objects (in a typed environment)

    # execute step in a pipeline environment
    Activity::Pipeline.TaskAdapter::Value # compute the return value (and also return the mutated object)
  end


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
