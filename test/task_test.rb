require "test_helper"

class TaskTest < Minitest::Spec

end

class TaskInvokerTest < Minitest::Spec
  class MyExecContext
    def my_circuit_interface_task(ctx, **kwars)
      ctx = ctx.merge(
        captured_ctx: CU.inspect(ctx),
        captured_kwargs: CU.inspect(kwars)
      )

      return ctx, Trailblazer::Activity::Left
    end
  end

  describe "Invoker::CircuitInterface" do
    it "exposes #call and invokes a callable" do
      ctx = {params: {}}.freeze

      _ctx, signal, _ = Trailblazer::Activity::Task::Invoker::CircuitInterface.(MyExecContext.new.method(:my_circuit_interface_task), ctx, exec_context: "self")

      assert_equal ctx, {params: {}} # not mutated.
      assert_equal _ctx, {:params=>{}, :captured_ctx=>"{:params=>{}}", :captured_kwargs=>"{:params=>{}, :exec_context=>\"self\"}"}
      assert_equal signal, Trailblazer::Activity::Left
      assert_nil _
    end
  end

  describe "Invoker::CircuitInterface::InstanceMethod" do
    it "exposes #call and invokes an instance method on :exec_context, not passing down circuit_options" do
      ctx = {params: {}}.freeze

      _ctx, signal, _ = Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod.(:my_circuit_interface_task, ctx, exec_context: MyExecContext.new, bogus: true)

      assert_equal ctx, {params: {}} # not mutated.
      assert_equal _ctx, {:params=>{}, :captured_ctx=>"{:params=>{}}", :captured_kwargs=>"{:params=>{}}"}
      assert_equal signal, Trailblazer::Activity::Left
      assert_nil _
    end
  end
end

class StepInvokerTest < Minitest::Spec
  class MyExecContext
    def my_step(ctx, **kwars)
      ctx = ctx.merge!(
        captured_ctx: CU.inspect(ctx),
        captured_kwargs: CU.inspect(kwars)
      )

      return true
    end
  end

  describe "Invoker::StepInterface" do
    it "exposes #call and invokes a callable" do
      ctx = {application_ctx: {params: {}}}#.freeze

      new_ctx, signal = Trailblazer::Activity::Task::Invoker::StepInterface.(MyExecContext.new.method(:my_step), ctx, exec_context: "self")

      assert_nil signal
      assert_equal CU.inspect(ctx), ctx_inspect = %({:application_ctx=>{:params=>{}, :captured_ctx=>"{:params=>{}}", :captured_kwargs=>"{:params=>{}}"}, :value=>true})
      assert_equal CU.inspect(new_ctx), ctx_inspect
    end
  end

  describe "Invoker::StepInterface::InstanceMethod" do
    it "exposes #call and invokes an instance method on :exec_context, not passing down circuit_options" do
      ctx = {application_ctx: {params: {}}}#.freeze

      new_ctx, signal = Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod.(:my_step, ctx, exec_context: MyExecContext.new)

      assert_nil signal
      assert_equal CU.inspect(ctx), ctx_inspect = %({:application_ctx=>{:params=>{}, :captured_ctx=>"{:params=>{}}", :captured_kwargs=>"{:params=>{}}"}, :value=>true})
      assert_equal CU.inspect(new_ctx), ctx_inspect
    end
  end
end
