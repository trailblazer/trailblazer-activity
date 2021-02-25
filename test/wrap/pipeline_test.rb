require "test_helper"

# Activity::Instance
#   .()
#   self[:task_wrap, :bla]
#
# Activity::Path
#   DSL
#   Instance (was {Process})
class PipelineTest < Minitest::Spec
  Pipeline = Activity::TaskWrap::Pipeline

  describe "Runner" do
    let(:task) { implementing.method(:a) }

    it "only calls task if no {wrap_static}" do
      # compile time
      static_task_wrap = Pipeline.new([["task_wrap.call_task", Activity::TaskWrap.method(:call_task)]]) # initial sequence

      # run-time
      original_args = [{seq: []}, {}]

      # no static_wrap
      signal, args = Activity::TaskWrap::Runner.(task, original_args, wrap_runtime: {}, activity: {wrap_static: {task => static_task_wrap}})

      expect(signal.inspect).must_equal %{Trailblazer::Activity::Right}
      expect(args.inspect).must_equal %{[{:seq=>[:a]}, {}]}
    end

    it "uses the {wrap_static} when available" do
      # compile time
      static_task_wrap = Pipeline.new([["task_wrap.call_task", Activity::TaskWrap.method(:call_task)]]) # initial sequence

      # run-time/compile time
      merge = Pipeline::Merge.new(
        [Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
        [Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]]
      )

      wrap_static_for_task = merge.(static_task_wrap)

      # with static_wrap (implies a merge)
      original_args = [{seq: []}, {}]

      signal, args = Activity::TaskWrap::Runner.(task, original_args, **{wrap_runtime: {}, activity: {wrap_static: {task => wrap_static_for_task}}})

      expect(signal.inspect).must_equal %{Trailblazer::Activity::Right}
      expect(args.inspect).must_equal %{[{:seq=>[1, :a, 2]}, {}]}
    end
  end

  describe "Pipeline" do
    it do
      pipe1 = Activity::TaskWrap::Pipeline.new([["task_wrap.call_task", Activity::TaskWrap.method(:call_task)]]) # initial sequence
      pipe2 = Activity::TaskWrap::Pipeline.insert_before(pipe1, "task_wrap.call_task", ["user.add_1", 2])
      pipe3 = Activity::TaskWrap::Pipeline.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", 3])
      pipe4 = Activity::TaskWrap::Pipeline.append(pipe3, nil, ["user.add_2", "Last!"])

      _(pipe1.sequence.inspect).must_match %r{\["task_wrap.call_task", #<Method: Trailblazer::Activity::TaskWrap.call_task.*}
      _(pipe4.sequence.inspect).must_match %r{\["user.add_1", 2\]}
      _(pipe4.sequence.inspect).must_match %r{\["user.add_2", 3\]}
      _(pipe4.sequence.inspect).must_match %r{\["user.add_2", "Last!"\]}
    end
  end
end
