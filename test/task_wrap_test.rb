require "test_helper"

class TaskWrapTest < Minitest::Spec
  def wrap_static(start, b, c, failure, success, **options)
    # extensions could be used to extend a particular task_wrap.
    {
      start => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      b => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      c => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      failure => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      success => Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP,
      **options
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
    tasks = Fixtures.default_tasks

    wrap_static = wrap_static(*tasks.values)

    hsh = Fixtures.flat_activity(tasks: tasks, config: {wrap_static: wrap_static}).to_h

    assert_equal hsh.keys, [:circuit, :outputs, :nodes, :config] # These four keys are required by the Trailblazer::Activity interface.
    assert_equal hsh[:config].keys, [:wrap_static]
    assert_equal hsh[:config][:wrap_static].keys, tasks.values

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

    tasks = Fixtures.default_tasks
    _, b, c = tasks.values

    wrap_static = wrap_static(*tasks.values)

    # Replace the taskWrap fo {c} with an extended one.
    original_tw_for_c = wrap_static[c]
    wrap_static = wrap_static.merge(c => ext.(original_tw_for_c))

    activity    = Fixtures.flat_activity(tasks: tasks, config: {wrap_static: wrap_static})

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
    tasks = Fixtures.default_tasks

    activity = Fixtures.flat_activity(tasks: tasks, config: {wrap_static: wrap_static(*tasks.values)})
    b        = tasks.fetch("b")

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
    tasks = Fixtures.default_tasks

    activity = Fixtures.flat_activity(tasks: tasks, config: {wrap_static: wrap_static(*tasks.values)})

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
  it "allows changing {:circuit_options} via a taskWrap step, but only locally" do
    flat_tasks = Fixtures.default_tasks

    flat_wrap_static = wrap_static(*flat_tasks.values)

    flat_activity = Fixtures.flat_activity(tasks: flat_tasks, config: {wrap_static: flat_wrap_static})

    tasks = Fixtures.default_tasks("c" => flat_activity)

    # Replace the taskWrap fo {flat_activity} with an extended one.
    ext = Trailblazer::Activity::TaskWrap.Extension(
      [method(:change_start_task), id: "my.change_start_task", prepend: nil],
    )

    wrap_static = wrap_static(
      *tasks.values,
      flat_activity => ext.(Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP), # extended.
    )

    failure, success = flat_activity.to_h[:outputs]
    wiring = Fixtures.default_wiring(tasks, flat_activity => {failure.signal => tasks["End.failure"], success.signal => tasks["End.success"]} )
    activity = Fixtures.flat_activity(tasks: tasks, wiring: wiring, config: {wrap_static: wrap_static})

    # Note the custom user-defined {:start_at} circuit option.
    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: [], start_at: flat_tasks.fetch("c")}, {}])

    # We run activity.c, then only flat_activity.c as we're skipping the inner {b} step.
    assert_equal CU.inspect(ctx), %({:seq=>[:b, :c], :start_at=>#{flat_tasks.fetch("c").inspect}})
    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
  end

  def change_circuit_options(wrap_ctx, original_args)
    (ctx, flow_options), circuit_options = original_args

    circuit_options.merge!( # DISCUSS: do this like an adult.
      this_is_only_visible_in_this_very_step: true
    )

    return wrap_ctx, original_args
  end

  # DISCUSS: maybe we can set the {:runner} in a tw step and then check that only the "current" task is affected?
  it "when changing {circuit_options}, it can only be seen in that very step. The following step sees the original {circuit_options}" do
    # trace {circuit_options} in {c}.
    step_c = ->((ctx, flow_options), **circuit_options) { ctx[:circuit_options] = circuit_options.keys; [Trailblazer::Activity::Right, [ctx, flow_options]] }

    tasks = Fixtures.default_tasks("c" => step_c)

    # in {b}'s taskWrap, we tamper with {circuit_options}.
    ext = Trailblazer::Activity::TaskWrap.Extension(
      [method(:change_circuit_options), id: "my.change_circuit_options", prepend: nil],
    )

    wrap_static = wrap_static(
      *tasks.values,
      tasks.fetch("b") => ext.(Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP), # extended.
    )

    activity = Fixtures.flat_activity(tasks: tasks, config: {wrap_static: wrap_static})

    signal, (ctx, flow_options) = Trailblazer::Activity::TaskWrap.invoke(activity, [{seq: []}, {}], key_for_circuit_options: true)

    # We run activity.c, then only flat_activity.c as we're skipping the inner {b} step.
    assert_equal CU.inspect(ctx), %({:seq=>[:b], :circuit_options=>[:key_for_circuit_options, :wrap_runtime, :activity, :runner]})
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
