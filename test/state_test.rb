require "test_helper"

class StateTest < Minitest::Spec
  describe "@state" do
    it "doesn't share state across classes" do
      create = Module.new do
        extend Activity::Path()
        task task: T.def_task(:a)
        task task: T.def_task(:b)
      end

      update = Module.new do
        extend Activity::Path()
        task task: T.def_task(:a)
        task task: T.def_task(:c)
      end

      signal, (ctx, _) = create.([ {seq: []}, {} ])
      ctx.must_equal({:seq=>[:a, :b]})

      signal, (ctx, _) = update.([ {seq: []}, {} ])
      ctx.must_equal({:seq=>[:a, :c]})
    end

  end
end
