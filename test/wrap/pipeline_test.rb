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
      signal, args = Activity::TaskWrap::Runner.(task, original_args, {wrap_runtime: {}, activity: {wrap_static: {task => static_task_wrap}}})

      signal.inspect.must_equal %{Trailblazer::Activity::Right}
      args.inspect.must_equal %{[{:seq=>[:a]}, {}]}
    end

    it "uses the {wrap_static} when available" do
# compile time
      static_task_wrap = Pipeline.new([["task_wrap.call_task", Activity::TaskWrap.method(:call_task)]]) # initial sequence

      # run-time/compile time
      merge = Pipeline::Merge.new(
        [Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
        [Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]],
      )

      wrap_static_for_task = merge.(static_task_wrap)

# with static_wrap (implies a merge)
      original_args = [{seq: []}, {}]

      signal, args = Activity::TaskWrap::Runner.(task, original_args, {wrap_runtime: {}, activity: {wrap_static: {task => wrap_static_for_task}}})

      signal.inspect.must_equal %{Trailblazer::Activity::Right}
      args.inspect.must_equal %{[{:seq=>[1, :a, 2]}, {}]}
    end
  end

  it "one Runner() go" do







    # pipe2 = merge.(static_task_wrap)

    # insert_after
    # prepend
    # append

    # this happens in {TaskWrap::Runner}.
    # wrap_ctx      = {task: task}

    # wrap_ctx, original_args = pipe2.(wrap_ctx, original_args)
    # original_args[0].inspect.must_equal %{{:seq=>[1, :a, 2]}}

    # # no mutation!
    # wrap_ctx, original_args = static_task_wrap.(wrap_ctx, [{seq: []}, {}])
    # original_args[0].inspect.must_equal %{{:seq=>[:a]}}

    # signal, args = wrap_ctx[:return_signal], wrap_ctx[:return_args]

=begin
gem "benchmark-ips"
require "benchmark/ips"

    pipe__ = Activity::TaskWrap::Pipeline2.new([["task_wrap.call_task", Activity::TaskWrap.method(:call_task)]]) # initial sequence

Benchmark.ips do |x|
  x.report("insert") {
    pipe2 = Activity::TaskWrap::Pipeline2.insert_before(pipe__, "task_wrap.call_task", ["user.add_1", method(:add_1)])
    pipe2 = Activity::TaskWrap::Pipeline2.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", method(:add_2)])
    pipe2 = Activity::TaskWrap::Pipeline2.insert_before(pipe2, "task_wrap.call_task", ["user.add_1", method(:add_1)])
    pipe2 = Activity::TaskWrap::Pipeline2.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", method(:add_2)])
    pipe2 = Activity::TaskWrap::Pipeline2.insert_before(pipe2, "task_wrap.call_task", ["user.add_1", method(:add_1)])
    pipe2 = Activity::TaskWrap::Pipeline2.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", method(:add_2)])
# pp pipe2
# raise
   }
  x.report("+") {
    pipe2 = Activity::TaskWrap::Pipeline.insert_before(pipe1, "task_wrap.call_task", ["user.add_1", method(:add_1)])
    pipe2 = Activity::TaskWrap::Pipeline.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", method(:add_2)])
    pipe2 = Activity::TaskWrap::Pipeline.insert_before(pipe2, "task_wrap.call_task", ["user.add_1", method(:add_1)])
    pipe2 = Activity::TaskWrap::Pipeline.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", method(:add_2)])
    pipe2 = Activity::TaskWrap::Pipeline.insert_before(pipe2, "task_wrap.call_task", ["user.add_1", method(:add_1)])
    pipe2 = Activity::TaskWrap::Pipeline.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", method(:add_2)])
# pp pipe2
# raise
   }

  x.compare!
end
=end



  end
end
