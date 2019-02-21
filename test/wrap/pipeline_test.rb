require "test_helper"

class PipelineTest < Minitest::Spec

  def add_1(wrap_ctx, original_args)
    ctx, _ = original_args
    ctx[:seq] << 1
    return wrap_ctx, original_args # yay to mutable state. not.
  end
  def add_2(wrap_ctx, original_args)
    ctx, _ = original_args
    ctx[:seq] << 2
    return wrap_ctx, original_args # yay to mutable state. not.
  end

  it "one Runner() go" do
    task = implementing.method(:a)



    # compile time
    pipe1 = Activity::TaskWrap::Pipeline.new([["task_wrap.call_task", Activity::TaskWrap.method(:call_task)]]) # initial sequence

    # run-time/compile time
    pipe2 = Activity::TaskWrap::Pipeline.insert_before(pipe1, "task_wrap.call_task", ["user.add_1", method(:add_1)])
    pipe2 = Activity::TaskWrap::Pipeline.insert_after(pipe2,  "task_wrap.call_task", ["user.add_2", method(:add_2)])
    pp pipe2
    # insert_after
    # prepend
    # append

    original_args = [{seq: []}, {}]
    # this happens in {TaskWrap::Runner}.
    wrap_ctx      = {task: task}

    wrap_ctx, original_args = pipe2.(wrap_ctx, original_args)
    original_args[0].inspect.must_equal %{{:seq=>[1, :a, 2]}}

    # no mutation!
    wrap_ctx, original_args = pipe1.(wrap_ctx, [{seq: []}, {}])
    original_args[0].inspect.must_equal %{{:seq=>[:a]}}

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
