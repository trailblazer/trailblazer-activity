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

  # TODO: test that this would also work.
  # def method_missing(*)
  #   raise
  # end

  let(:ctx) { {params: {id: 1}, action: :update} }

  it "Circuit::Task.build" do
    # callable = Trailblazer::Activity::Circuit::Task.build(method(:my_output_with_circuit_interface)) # compile-toime
    circuit_task = Trailblazer::Activity::Circuit.Task(method(:my_output_with_circuit_interface)) # compile-toime

    return_set = circuit_task.(self.ctx, {stack: []}, {exec_context: self})
    # bla, translate binary...

    assert_equal return_set, [self.ctx, {stack: []}, {id: 1, exec_context: self}]


=begin
    callable_builder = Trailblazer::Activity::Circuit::Task.build(:my_output_with_circuit_interface)
    # Runtime
    callable = callable_builder.(self.ctx, {stack: []}, {exec_context: self})
=end
    circuit_task = Trailblazer::Activity::Circuit.Task(:my_output_with_circuit_interface)

    return_set = circuit_task.(self.ctx, {stack: []}, {exec_context: self}) # this calls the instance method on {exec_context} which is "extracted" before.
    # translate binary etc

    assert_equal return_set, [self.ctx, {stack: []}, {id: 1, exec_context: self}]
  end

  def my_rescue_handler(ctx, *, exception:)
    ctx[:exception_class] = exception.class
    return ctx, {}, :Right
  end
  it "Circuit::Task with kwargs" do
    callable = Trailblazer::Activity::Circuit.Task(:my_rescue_handler)

    # Runtime
    return_set = callable.(self.ctx, {stack: []}, {exec_context: self}, exception: Object.new)
    # translate binary etc

    assert_equal return_set, [self.ctx.merge(:exception_class=>Object), {}, :Right]
  end

  def my_rescue_handler_step(ctx, params:, **)
    ctx[:captured_params] = params.class
  end
  it "Circuit::Step with step interface" do
    ctx = self.ctx

    circuit_step = Trailblazer::Activity::Circuit.Step(:my_rescue_handler_step, binary: false)

    # Runtime
    return_set = circuit_step.(ctx, flow_options={stack: []}, {exec_context: self})
    # translate binary etc
    return_set = [ctx, flow_options, :Right]

    assert_equal return_set, [self.ctx.merge(captured_params: Hash), {stack: []}, :Right]
  end

  class MyStep
    def self.call(ctx, params:, **)
      ctx[:captured_params] = CU.inspect(params)
    end
  end

  # step interface returning a value.
  # def self.my_step(ctx, params:, **)
  #   ctx[:captured_params] = CU.inspect(params)
  # end

  def my_handler_with_step_interface(ctx, params:, **)
    ctx[:captured_params] = CU.inspect(params)
  end

  def my_binary_step_handler(ctx, outcome:, **)
    ctx[:my_binary_step_handler] = true

    outcome
  end

  it "ads;lfjsddsjfaksjflasflkaflajflkajfaj" do
    ctx, _flow_options, signal = Trailblazer::Activity::Circuit::Task___Activity::InstanceMethod.(
      {
        application_ctx: self.ctx,
        method_name: :my_output_with_circuit_interface
      }, {}, {exec_context: self}
      )

    assert_equal CU.strip(CU.inspect(ctx[:result][2]))[0..18], %({:id=>1, :exec_cont) # FIXME.
    assert_equal signal, Trailblazer::Activity::Right

    ctx, _ = Trailblazer::Activity::Circuit::Step___::Step___Activity___InstanceMethod.(
      {
        application_ctx: self.ctx,
        method_name: :my_handler_with_step_interface,
      }, {}, {exec_context: self}
      )

    assert_equal CU.strip(CU.inspect(ctx[:application_ctx]))[0..18], %({:params=>{:id=>1},) # FIXME.

    ctx, flow_options, signal = Trailblazer::Activity::Circuit::Step___::Step___Activity___InstanceMethod___Binary.(
      {
        application_ctx: {outcome: false, params: {id: 1}},
        method_name: :my_binary_step_handler,
      }, {}, {exec_context: self}
      )

    assert_equal signal, Trailblazer::Activity::Left
    assert_equal CU.strip(CU.inspect(ctx))[0..18], %({:id=>1}) # FIXME.
  end

  it "Circuit::Step with step interface, no binary, returning a value, only" do
    ctx = self.ctx

    circuit_step = Trailblazer::Activity::Circuit.Step(MyStep, binary: false)

    # Runtime
    value = circuit_step.(ctx, flow_options={stack: []}, {exec_context: self})
    # TODO: assert value?

    # translate binary etc
    return_set = [ctx, flow_options, :Right]

    assert_equal return_set, [self.ctx.merge(captured_params: "{:id=>1}"), {stack: []}, :Right]
  end

  it "Circuit::Step with step interface, binary translation" do
    circuit_step = Trailblazer::Activity::Circuit.Step(MyStep)

    # Runtime
    return_set = circuit_step.(ctx, flow_options={stack: []}, {exec_context: self})

    assert_equal return_set, [self.ctx.merge(captured_params: "{:id=>1}"), {stack: []}, Trailblazer::Activity::Right]
  end


  it "Circuit::Step with step interface :instance_method, binary translation" do
    circuit_step = Trailblazer::Activity::Circuit.Step(:my_handler_with_step_interface)

    # Runtime
    return_set = circuit_step.(ctx, flow_options={stack: []}, {exec_context: self})

    assert_equal return_set, [self.ctx.merge(captured_params: "{:id=>1}"), {stack: []}, Trailblazer::Activity::Right]
  end

=begin
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
=end
end
