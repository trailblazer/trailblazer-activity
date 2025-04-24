require "test_helper"

class TaskWrapTest < Minitest::Spec
  def wrap_static(start, b, c, failure, success)
    # extensions could be used to extend a particular task_wrap.
    {
      start => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      b => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      c => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      failure => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      success => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
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

    assert_equal hsh.keys, [:circuit, :outputs, :nodes, :config] # These four keys are required by the Trailblazer::Activity interface.
    assert_equal hsh[:config].keys, [:wrap_static]
    assert_equal hsh[:config][:wrap_static].keys, tasks

    pipeline_class = Trailblazer::Activity::TaskWrap::Pipeline
    call_task_inspect = [Trailblazer::Activity::TaskWrap::ROW_ARGS_FOR_CALL_TASK].inspect

    assert_equal hsh[:config][:wrap_static].values.collect { |value| value.class }, [pipeline_class, pipeline_class, pipeline_class, pipeline_class, pipeline_class]
    assert_equal hsh[:config][:wrap_static].values.collect { |value| value.to_a.inspect }, [call_task_inspect, call_task_inspect, call_task_inspect, call_task_inspect, call_task_inspect]
  end

  it "{:wrap_static} allows adding steps, e.g. via Extension" do
    ext = Trailblazer::Activity::TaskWrap.Extension(
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
      [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"],
    )

    _, b, c = tasks

    wrap_static = wrap_static(*tasks)

    # Replace the taskWrap fo {c} with an extended one.
    original_tw_for_c = wrap_static[c]
    wrap_static = wrap_static.merge(c => ext.(original_tw_for_c))

    activity    = flat_activity(config: {wrap_static: wrap_static})

    # tw is not used with normal {Trailblazer::Activity#call}.
    signal, (ctx, flow_options) = activity.call([{seq: []}, {}])

    assert_equal CU.inspect(ctx), %({:seq=>[:b, :c]})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)

    # With TaskWrap.invoke the tw is obviously incorporated.
    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}, {}])

    assert_equal CU.inspect(ctx), %({:seq=>[:b, 1, :c, 2]})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
  end

  it "{:wrap_runtime} allows adding tw extensions to specific tasks when invoking the activity" do
    activity = flat_activity(config: {wrap_static: wrap_static(*tasks)})
    _, b     = tasks

    wrap_runtime = {
      b => Trailblazer::Activity::TaskWrap.Extension(
        [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
        [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"],
      )
    }

    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}, {}], wrap_runtime: wrap_runtime)

    assert_equal CU.inspect(ctx), %({:seq=>[1, :b, 2, :c]})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
  end

  it "{:wrap_runtime} can also be a defaulted Hash. maybe we could allow having both, default steps and specific ones?" do
    activity = flat_activity(config: {wrap_static: wrap_static(*tasks)})

    wrap_runtime = Hash.new(
      Trailblazer::Activity::TaskWrap.Extension(
        [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
        [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"],
      )
    )

    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}, {}], wrap_runtime: wrap_runtime)

    assert_equal CU.inspect(ctx), %({:seq=>[1, 1, 2, 1, :b, 2, 1, :c, 2, 1, 2, 2]})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
  end

  def change_start_task(wrap_ctx, original_args)
    (ctx, flow_options), circuit_options = original_args

    circuit_options = circuit_options.merge(start_task: ctx[:start_at])
    original_args   = [[ctx, flow_options], circuit_options]

    return wrap_ctx, original_args
  end

  # Set start_task of {flat_activity} (which is nested in {nesting_activity}) to something else than configured in the
  # nested activity itself.
  # Instead of running {a -> {b -> c} -> success} it now goes {a -> {c} -> success}.
  it "allows changing {:circuit_options} via a taskWrap step" do
    nesting_builder = Class.new do
      include NestingActivity
    end.new

    flat_builder = Class.new do
      include FlatActivity
    end.new

    start, b, c, failure, success = flat_builder.tasks

    flat_wrap_static = {
      start => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      b => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      c => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      failure => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      success => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
    }

    flat_activity = flat_builder.flat_activity(config: {wrap_static: flat_wrap_static})

    tasks = nesting_builder.tasks(flat_activity: flat_activity)
    start, a, flat_activity, failure, success = tasks

    # Replace the taskWrap fo {flat_activity} with an extended one.
    ext = Trailblazer::Activity::TaskWrap.Extension(
      [method(:change_start_task), id: "my.change_start_task", prepend: nil],
    )

    wrap_static = {
      start => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      a => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      flat_activity => ext.(Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP), # extended.
      failure => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      success => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
    }

    activity = nesting_builder.activity(tasks: tasks, config: {wrap_static: wrap_static})

    # Note the custom user-defined {:start_at} circuit option.
    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: [], start_at: c}, {}])

    assert_equal CU.inspect(ctx), %({:seq=>[:a, :c], :start_at=>#{c.inspect}})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
  end

  describe "{TaskWrap.container_activity_for}" do
    it "accepts {:wrap_static} option" do
      host_activity = Trailblazer::Activity::TaskWrap.container_activity_for(Object, wrap_static: {a: 1})

      assert_equal CU.inspect(host_activity), "{:config=>{:wrap_static=>{Object=>{:a=>1}}}, :nodes=>{Object=>#<struct Trailblazer::Activity::Schema::Nodes::Attributes id=nil, task=Object, data=nil, outputs=nil>}}"
    end

    it "if {:wrap_static} not given it adds {#initial_wrap_static}" do
      host_activity = Trailblazer::Activity::TaskWrap.container_activity_for(Object)

      assert_equal CU.inspect(host_activity), "{:config=>{:wrap_static=>{Object=>#{Trailblazer::Activity::TaskWrap.initial_wrap_static.inspect}}}, :nodes=>{Object=>#<struct Trailblazer::Activity::Schema::Nodes::Attributes id=nil, task=Object, data=nil, outputs=nil>}}"
    end

    it "accepts additional options for {:config}, e.g. {each: true}" do
      host_activity = Trailblazer::Activity::TaskWrap.container_activity_for(Object, each: true)

      assert_equal CU.inspect(host_activity), "{:config=>{:wrap_static=>{Object=>#{Trailblazer::Activity::TaskWrap.initial_wrap_static.inspect}}, :each=>true}, :nodes=>{Object=>#<struct Trailblazer::Activity::Schema::Nodes::Attributes id=nil, task=Object, data=nil, outputs=nil>}}"

    # allows mixing
      host_activity = Trailblazer::Activity::TaskWrap.container_activity_for(Object, each: true, wrap_static: {a: 1})

      assert_equal CU.inspect(host_activity), "{:config=>{:wrap_static=>{Object=>{:a=>1}}, :each=>true}, :nodes=>{Object=>#<struct Trailblazer::Activity::Schema::Nodes::Attributes id=nil, task=Object, data=nil, outputs=nil>}}"
    end

    it "accepts {:id}" do
      host_activity = Trailblazer::Activity::TaskWrap.container_activity_for(Object, id: :OBJECT)

      assert_equal CU.inspect(host_activity), "{:config=>{:wrap_static=>{Object=>#{Trailblazer::Activity::TaskWrap.initial_wrap_static.inspect}}}, :nodes=>{Object=>#<struct Trailblazer::Activity::Schema::Nodes::Attributes id=:OBJECT, task=Object, data=nil, outputs=nil>}}"
    end
  end # {TaskWrap.container_activity_for}
end
