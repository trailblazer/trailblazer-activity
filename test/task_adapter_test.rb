require "test_helper"

class TaskAdapterTest < Minitest::Spec
  class Operation
    def process_type(ctx, model:, **)
      return if model.nil?

      ctx[:type] = model.class
    end
  end

  it "Circuit::TaskAdapter" do


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
    circuit_task  = Activity::Circuit::TaskAdapter.for_step(step, option: true)

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

    ctx = {model: nil}
    signal, (ctx, flow_options) = circuit_task.([ctx, flow_options], **circuit_options, exec_context: Operation.new)

    assert_equal signal, Trailblazer::Activity::Left
    assert_equal ctx.inspect, %{{:model=>nil}}
    assert_equal flow_options.inspect, %{{}}

#@ pipeline-interface

    # we don't have {:exec_context} in a Pipeline!
    step = Operation.new.method(:process_type)
    args = [1,2]
    ctx  = {model: Object}

    pipeline_task = Activity::TaskWrap::Pipeline::TaskAdapter.for_step(step) # Task receives circuit-interface but it's compatible with Pipeline interface
    wrap_ctx, args = pipeline_task.(ctx, args) # that's how pipeline tasks are called in {TaskWrap::Pipeline}.

    assert_equal wrap_ctx.inspect, %{{:model=>Object, :type=>Class}}
    assert_equal args, [1,2]
  end

  it "deprecation of {TaskBuilder} and backward-compat" do
    task_adapter = nil
    _, warning = capture_io do
      task_adapter = Activity::TaskBuilder.Binary(:process_type)
    end
    line_number_for_binary = __LINE__ - 2

    lines = warning.split("\n")
    lines[0] = lines[0][0..-5]+"." if lines[0] =~ /\d-\d+-\d/
    warning = lines.join("\n")

    assert_equal warning, %{NOTE: Trailblazer::Activity::TaskBuilder.Binary is deprecated; use Trailblazer::Activity::Circuit::TaskAdapter.for_step() instead. It will be removed on or after 2023-12.
Trailblazer::Activity::TaskBuilder.Binary called from #{File.realpath(__FILE__)}:#{line_number_for_binary}.}

    assert_equal task_adapter.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=process_type>}

    signal, (ctx, flow_options) = task_adapter.([{model: Object}, {}], exec_context: Operation.new)

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal ctx.inspect, %{{:model=>Object, :type=>Class}}
    assert_equal flow_options.inspect, %{{}}
  end

  # TODO: properly test {TaskAdapter#inspect}.

  it "AssignVariable" do
    skip "# DISCUSS: Do we need AssignVariable?"

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
