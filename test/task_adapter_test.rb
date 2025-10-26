require "test_helper"

class TaskAdapterTest < Minitest::Spec
  class Operation
    def process_type(ctx, model:, **)
      return if model.nil?

      ctx[:type] = model.class
    end
  end

  def my_output(ctx, params:, **)
    {
      id: params[:id],
    }
  end

  def my_output_with_circuit_interface(ctx, flow_options, circuit_options)
    value = {
      id:           ctx[:params][:id],
      exec_context: circuit_options[:exec_context],
    }

    return ctx, flow_options, value
  end

  let(:ctx) { {params: {id: 1}, action: :update} }

  it "Option::InstanceMethod" do
  # instance method with step interface
    option = Trailblazer::Activity::Option::InstanceMethod.new(:my_output)

    circuit_options = {exec_context: self, wrap_runtime: {}}

    value = option.(self.ctx, keyword_arguments: self.ctx.to_hash, **circuit_options)

    assert_equal value, {id: 1}

  # instance method with different interface, for example, circuit interface (how surprising!)
    option = Trailblazer::Activity::Option::InstanceMethod.new(:my_output_with_circuit_interface)

    ctx, flow_options, value = option.(self.ctx, flow_options, circuit_options, **circuit_options) # DISCUSS: omitting {:keyword_arguments} might lead to problems in Ruby < 2.7.

    assert_equal value, {id: 1, exec_context: self}
    assert_equal ctx, self.ctx
  end

  it "Circuit.Step" do
  # callable with step interface
    task_to_step = Trailblazer::Activity::Circuit.Step(method(:my_output))

    # this is how it'd be executed in the Circuit.
    ctx, flow_options, value = task_to_step.(self.ctx, {stack: []}, {exec_context: self})
    assert_equal ctx, self.ctx
    assert_equal flow_options, {stack: []}
    assert_equal value, {id: 1}

  # :instance_method with step interface
    task_to_step = Trailblazer::Activity::Circuit.Step(:my_output, instance_method: true)

    ctx, flow_options, value = task_to_step.(self.ctx, {stack: []}, {exec_context: self})
    assert_equal ctx, self.ctx
    assert_equal flow_options, {stack: []}
    assert_equal value, {id: 1}
  end

  def my_output_decider(ctx, valid:, **)
    ctx[:seq] << :my_output_decider

    valid
  end

  describe "with binary wrapping" do
    def ctx
      {seq: [], valid: true}
    end

# TODO: test that we can return {flow_options}.

    it "with callable" do
    # callable with step interface
      step = Trailblazer::Activity::Circuit.Step(method(:my_output_decider), binary: true)

      # this is how it'd be executed in the Circuit.
      ctx, flow_options, signal = step.(self.ctx, {stack: []}, {exec_context: self})
      assert_equal CU.inspect(ctx), %({:seq=>[:my_output_decider], :valid=>true})
      assert_equal flow_options, {stack: []}
      assert_equal signal, Trailblazer::Activity::Right

      left_ctx = self.ctx().merge(valid: false)

      ctx, flow_options, signal = step.(left_ctx, {stack: []}, {exec_context: self})
      assert_equal CU.inspect(ctx), %({:seq=>[:my_output_decider], :valid=>false})
      assert_equal flow_options, {stack: []}
      assert_equal signal, Trailblazer::Activity::Left
    end

    it "{:instance_method} with step interface" do
      step = Trailblazer::Activity::Circuit.Step(:my_output_decider, instance_method: true, binary: true)

      ctx, flow_options, signal = step.(self.ctx, {stack: []}, {exec_context: self})
      assert_equal CU.inspect(ctx), %({:seq=>[:my_output_decider], :valid=>true})
      assert_equal flow_options, {stack: []}
      assert_equal signal, Trailblazer::Activity::Right

      left_ctx = self.ctx.merge(valid: false)

      ctx, flow_options, signal = step.(left_ctx, {stack: []}, {exec_context: self})
      assert_equal CU.inspect(ctx), %({:seq=>[:my_output_decider], :valid=>false})
      assert_equal flow_options, {stack: []}
      assert_equal signal, Trailblazer::Activity::Left
    end
  end

#   it "Circuit::TaskAdapter" do


#     # steps receive ctx and kwargs
#     # steps can write to something
#     # steps return an outcome "boolean"/return value
#     step = ->(ctx, model:, **) do
#       return if model.nil?

#       ctx[:type] = model.class
#     end

#     flow_options    = {}
#     circuit_options = {}

#     ctx             = {model: nil}

#   # execute step in a circuit-interface environment
#     circuit_step = Trailblazer::Activity::Circuit::Step(step) # circuit step receives circuit-interface but returns only value
#     return_value, ctx = circuit_step.([ctx, flow_options], **circuit_options)

#     assert_nil return_value
#     assert_equal CU.inspect(ctx), %{{:model=>nil}}


#   #@ execute step-option in a circuit-interface environment
#     circuit_step = Trailblazer::Activity::Circuit.Step(step, option: true) # wrap step with Trailblazer::Option
#     return_value, ctx = circuit_step.([ctx, flow_options], **circuit_options, exec_context: self)
#     assert_nil return_value
#     assert_equal CU.inspect(ctx), %{{:model=>nil}}

#     circuit_step = Trailblazer::Activity::Circuit::Step(:process_type, option: true) # wrap step with Trailblazer::Option
#     return_value, ctx = circuit_step.([ctx, flow_options], **circuit_options, exec_context: Operation.new)
#     assert_nil return_value
#     assert_equal CU.inspect(ctx), %{{:model=>nil}}

#   #@ circuit-interface Option-compatible Step that does a Binary signal decision
#     step          = :process_type
#     circuit_task  = Trailblazer::Activity::Circuit::TaskAdapter.for_step(step, option: true)

#     ctx = {model: nil}
#     signal, (ctx, flow_options) = circuit_task.([ctx, flow_options], **circuit_options, exec_context: Operation.new)

#     assert_equal signal, Trailblazer::Activity::Left
#     assert_equal CU.inspect(ctx), %{{:model=>nil}}
#     assert_equal flow_options.inspect, %{{}}

#     ctx = {model: Object}
#     signal, (ctx, flow_options) = circuit_task.([ctx, flow_options], **circuit_options, exec_context: Operation.new)

#     assert_equal signal, Trailblazer::Activity::Right
#     assert_equal CU.inspect(ctx), %{{:model=>Object, :type=>Class}}
#     assert_equal flow_options.inspect, %{{}}

#     ctx = {model: nil}
#     signal, (ctx, flow_options) = circuit_task.([ctx, flow_options], **circuit_options, exec_context: Operation.new)

#     assert_equal signal, Trailblazer::Activity::Left
#     assert_equal CU.inspect(ctx), %{{:model=>nil}}
#     assert_equal flow_options.inspect, %{{}}

# #@ pipeline-interface

#     # we don't have {:exec_context} in a Pipeline!
#     step = Operation.new.method(:process_type)
#     args = [1,2]
#     ctx  = {model: Object}

#     # FIXME: remove, this has been moved to DSL.
#     # pipeline_task = Trailblazer::Activity::TaskWrap::Pipeline::TaskAdapter.for_step(step) # Task receives circuit-interface but it's compatible with Pipeline interface
#     # wrap_ctx, args = pipeline_task.(ctx, args) # that's how pipeline tasks are called in {TaskWrap::Pipeline}.

#     # assert_equal CU.inspect(wrap_ctx), %{{:model=>Object, :type=>Class}}
#     # assert_equal args, [1,2]
#   end

  # TODO: properly test {TaskAdapter#inspect}.

  it "AssignVariable" do
    skip "# DISCUSS: Do we need AssignVariable?"

    decider = ->(ctx, mode:, **) { mode }

    circuit_task = Trailblazer::Activity::Circuit::TaskAdapter.Binary(
      decider,
      adapter_class: Trailblazer::Activity::Circuit::TaskAdapter::Step::AssignVariable,
      variable_name: :nested_activity
    )

    ctx = {mode: Object}
    signal, (ctx, flow_options) = circuit_task.([ctx, {}], **{exec_context: nil})

    assert_equal signal, Trailblazer::Activity::Right
    assert_equal CU.inspect(ctx), %{{:mode=>Object, :nested_activity=>Object}}

  #@ returning false
    ctx = {mode: false}
    signal, (ctx, flow_options) = circuit_task.([ctx, {}], **{exec_context: nil})

    assert_equal signal, Trailblazer::Activity::Left
    assert_equal CU.inspect(ctx), %{{:mode=>false, :nested_activity=>false}}
  end

end
