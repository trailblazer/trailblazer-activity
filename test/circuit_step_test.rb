require "test_helper"

class CircuitStepTest < Minitest::Spec
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

  it "Circuit.Step" do
  # callable with step interface
    task_to_step = Trailblazer::Activity::Circuit.Step(method(:my_output))

    # this is how it'd be executed in the Circuit.
    ctx, flow_options, value = task_to_step.(self.ctx, {stack: []}, {exec_context: self})
    assert_equal ctx, self.ctx
    assert_equal flow_options, {stack: []}
    assert_equal value, {id: 1}

  # :instance_method with step interface
    task_to_step = Trailblazer::Activity::Circuit.Step(:my_output)

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
      step = Trailblazer::Activity::Circuit.Step(:my_output_decider, binary: true)

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

  describe "implementing something like AssignVariable" do
    def ctx
      {seq: [], valid: true}
    end

    class MySignalDecider < Trailblazer::Activity::Circuit::Step
      def call(ctx, flow_options, circuit_options)
        ctx, flow_options, value = @step.(ctx, flow_options, circuit_options)

        ctx[:my_variable] = value

        return ctx, flow_options, value
      end
    end

    it "what" do
      step = Trailblazer::Activity::Circuit.Step(method(:my_output_decider), binary: MySignalDecider)

      # this is how it'd be executed in the Circuit.
      ctx, flow_options, signal = step.(self.ctx, {stack: []}, {exec_context: self})
      assert_equal CU.inspect(ctx), %({:seq=>[:my_output_decider], :valid=>true, :my_variable=>true})
      assert_equal flow_options, {stack: []}
      assert_equal signal, true

    end
  end
end
