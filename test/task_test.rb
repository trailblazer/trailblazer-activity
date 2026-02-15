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
