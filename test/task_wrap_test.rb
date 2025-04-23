require "test_helper"

class TaskWrapTest < Minitest::Spec
  def wrap_static(start, b, c, failure, success)
    # extensions could be used to extend a particular task_wrap.
    {
      start => Activity::TaskWrap::INITIAL_TASK_WRAP,
      b => Activity::TaskWrap::INITIAL_TASK_WRAP,
      c => Activity::TaskWrap::INITIAL_TASK_WRAP,
      failure => Activity::TaskWrap::INITIAL_TASK_WRAP,
      success => Activity::TaskWrap::INITIAL_TASK_WRAP,
    }
  end

  def add_1(wrap_ctx, original_args)
    ctx, = original_args[0]
    ctx[:seq] << 1
    return wrap_ctx, original_args # yay to mutable state. not.
  end

  def add_2(wrap_ctx, original_args)
    ctx, = original_args[0]
    ctx[:seq] << 2
    return wrap_ctx, original_args # yay to mutable state. not.
  end

  it "exposes {#to_h} that includes {:wrap_static}" do
    wrap_static = wrap_static(*tasks)

    hsh = flat_activity(config: {wrap_static: wrap_static}).to_h

    assert_equal hsh.keys, [:circuit, :outputs, :nodes, :config] # These four keys are required by the Activity interface.
    assert_equal hsh[:config].keys, [:wrap_static]
    assert_equal hsh[:config][:wrap_static].keys, tasks

    pipeline_class = Activity::TaskWrap::Pipeline
    call_task_inspect = [Activity::TaskWrap::ROW_ARGS_FOR_CALL_TASK].inspect

    assert_equal hsh[:config][:wrap_static].values.collect { |value| value.class }, [pipeline_class, pipeline_class, pipeline_class, pipeline_class, pipeline_class]
    assert_equal hsh[:config][:wrap_static].values.collect { |value| value.to_a.inspect }, [call_task_inspect, call_task_inspect, call_task_inspect, call_task_inspect, call_task_inspect]
  end

  it "{:wrap_static} allows adding steps, e.g. via Extension" do
    ext = Trailblazer::Activity::TaskWrap.Extension(
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
      [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"],
    )

    _, b, c, _ = tasks

    wrap_static = wrap_static(*tasks)

    original_tw_for_c = wrap_static[c]
    wrap_static = wrap_static.merge(c => ext.(original_tw_for_c))

    activity    = flat_activity(config: {wrap_static: wrap_static})

    # tw is not used with normal {Activity#call}.
    signal, (ctx, flow_options) = activity.call([{seq: []}, {}])

    assert_equal CU.inspect(ctx), %({:seq=>[:b, :c]})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)

    # With TaskWrap.invoke the tw is obviously incorporated.
    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}, {}])

    assert_equal CU.inspect(ctx), %({:seq=>[:b, 1, :c, 2]})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
  end
end
