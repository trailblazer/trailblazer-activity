require "test_helper"

# Test taskWrap concepts along with {Instance}s.
class TaskWrapTest < Minitest::Spec
  def abc_intermediate
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
  end

  def abc_implementation(a_extensions: [])
    implementation = {
      :a => Schema::Implementation::Task(implementing.method(:a), [Activity::Output(Activity::Right, :success)], a_extensions),
      :b => Schema::Implementation::Task(implementing.method(:b), [Activity::Output(Activity::Right, :success)],                 []),
      :c => Schema::Implementation::Task(implementing.method(:c), [Activity::Output(Activity::Right, :success)],                 []),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], []) # DISCUSS: End has one Output, signal is itself?
    }

    return implementation, _es
  end

  it "populates activity[:wrap_static] and uses it at run-time" do
    merge = [
      [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
      [TaskWrap::Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]]
    ]

    abc_implementation, _es = abc_implementation(a_extensions: [TaskWrap::Extension(merge: merge)])

    schema = Inter.(abc_intermediate, abc_implementation)

    _signal, (ctx, _flow_options) = TaskWrap.invoke(Activity.new(schema), [{seq: []}], **{})

    expect(ctx.inspect).must_equal %{{:seq=>[1, :a, 2, :b, :c]}}

    # it works nested as well

    top_implementation = {
      :a => Schema::Implementation::Task(implementing.method(:a), [Activity::Output(Activity::Right, :success)], []),
      :b => Schema::Implementation::Task(Activity.new(schema), [Activity::Output(_es, :success)], []),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                 [TaskWrap::Extension(merge: merge)]),
      "End.success" => Schema::Implementation::Task(es = implementing::Success, [Activity::Output(implementing::Success, :success)], []) # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(abc_intermediate, top_implementation)

    _signal, (ctx, _flow_options) = TaskWrap.invoke(Activity.new(schema), [{seq: []}], **{})

    expect(ctx.inspect).must_equal %{{:seq=>[:a, 1, :a, 2, :b, :c, 1, :c, 2]}}

    # it works nested plus allows {wrap_runtime}

    wrap_runtime = {c => TaskWrap::Pipeline::Merge.new(*merge)}

    _signal, (ctx, _flow_options) = TaskWrap.invoke(Activity.new(schema), [{seq: []}], **{wrap_runtime: wrap_runtime})

    expect(ctx.inspect).must_equal %{{:seq=>[:a, 1, :a, 2, :b, 1, :c, 2, 1, 1, :c, 2, 2]}}
  end

# In a setup a-->b-->c it's possible to assign a taskWrap step to {a} (which is an activity) that changes a's {:start_task} but
# doesn't affect any of the following steps.
  it "allows changing {circuit_options} via taskWrap" do
    abc_implementation, _es = abc_implementation()

    inner_schema = Inter.(abc_intermediate, abc_implementation)

  # outer
    outer_intermediate = Inter.new(
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
      [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:change_start_task)]],
    ]

    outer_implementation = {
      :a => Schema::Implementation::Task(Activity.new(inner_schema), [Activity::Output(_es, :success)], [TaskWrap::Extension(merge: merge)]),
      :b => Schema::Implementation::Task(Activity.new(inner_schema), [Activity::Output(_es, :success)], []),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],      []),
      "End.success" => Schema::Implementation::Task(es = implementing::Success, [Activity::Output(implementing::Success, :success)], []) # DISCUSS: End has one Output, signal is itself?
    }

    outer_schema = Inter.(outer_intermediate, outer_implementation)

    _signal, (ctx, _flow_options) = TaskWrap.invoke(Activity.new(outer_schema), [{seq: [], start_at: start_at=implementing.method(:b)}], **{})

    assert_equal [:seq, :start_at], ctx.keys
    assert_equal [:b, :c, :a, :b, :c, :c], ctx[:seq]
    assert_equal start_at, ctx[:start_at]
  end

  def change_start_task(wrap_ctx, original_args)
    (ctx, flow_options), circuit_options = original_args

    circuit_options = circuit_options.merge(start_task: ctx[:start_at])

    original_args = [[ctx, flow_options], circuit_options]

    return wrap_ctx, original_args # yay to mutable state. not.
  end
end
