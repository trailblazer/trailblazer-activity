require "test_helper"

# Test taskWrap concepts along with {Instance}s.
class TaskWrapTest < Minitest::Spec
  it "populates activity[:wrap_static] and uses it at run-time" do
    intermediate = Inter.new(
      {
        Inter::TaskRef(:a) => [Inter::Out(:success, :b)],
        Inter::TaskRef(:b) => [Inter::Out(:success, :c)],
        Inter::TaskRef(:c) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      ["End.success"],
      [:a] # start
    )

    merge = [
      [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
      [TaskWrap::Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]],
    ]

    implementation = {
      :a => Schema::Implementation::Task(a = implementing.method(:a), [Activity::Output(Activity::Right, :success)],                 [TaskWrap::Extension(merge: merge, task: a)]),
      :b => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                 []),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                 []),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    signal, (ctx, flow_options) = TaskWrap.invoke(Activity.new(schema), [{seq: []}], **{})

    ctx.inspect.must_equal %{{:seq=>[1, :a, 2, :b, :c]}}

# it works nested as well

    top_implementation = {
      :a => Schema::Implementation::Task(a = implementing.method(:a), [Activity::Output(Activity::Right, :success)],                 []),
      :b => Schema::Implementation::Task(b = Activity.new(schema),     [Activity::Output(_es, :success)],                            []),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                 [TaskWrap::Extension(merge: merge, task: c)]),
      "End.success" => Schema::Implementation::Task(es = implementing::Success, [Activity::Output(implementing::Success, :success)], []), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, top_implementation)

    signal, (ctx, flow_options) = TaskWrap.invoke(Activity.new(schema), [{seq: []}], **{})

    ctx.inspect.must_equal %{{:seq=>[:a, 1, :a, 2, :b, :c, 1, :c, 2]}}

# it works nested plus allows {wrap_runtime}

    wrap_runtime = {c => TaskWrap::Pipeline::Merge.new(*merge)}

    signal, (ctx, flow_options) = TaskWrap.invoke(Activity.new(schema), [{seq: []}], **{wrap_runtime: wrap_runtime})

    ctx.inspect.must_equal %{{:seq=>[:a, 1, :a, 2, :b, 1, :c, 2, 1, 1, :c, 2, 2]}}
  end

end
