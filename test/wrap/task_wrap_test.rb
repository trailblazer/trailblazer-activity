require "test_helper"

# Test taskWrap concepts along with {Instance}s.
class TaskWrapTest < Minitest::Spec
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

#@ new extension API for runtime.
#@ friendly Interface tests.
  it "{Extension()} can be used as runtime extension" do
    abc_implementation, _es = abc_implementation()
    schema                  = Inter.(abc_intermediate, abc_implementation)

    c     = implementing.method(:c)
    c_ext = TaskWrap.Extension(
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
      [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"],
    )

    wrap_runtime = {c => c_ext}

    assert_invoke Activity.new(schema), seq: "[:a, :b, 1, :c, 2]", circuit_options: {wrap_runtime: wrap_runtime}

  #@ test: we can use other insert_ids.
    c_ext = TaskWrap.Extension(
      [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
      [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"],
    #@ these lines test if defaulting in Extension() works properly and doesn't override anything.
      [method(:add_2), id: "user.add_2.2", prepend: "user.add_1"], #@ prepend to added step
      [method(:add_1), id: "user.add_1.2", append: "user.add_2"], #@ prepend to added step
    )

    wrap_runtime = {c => c_ext}

    assert_invoke Activity.new(schema), seq: "[:a, :b, 2, 1, :c, 2, 1]", circuit_options: {wrap_runtime: wrap_runtime}

  #@ test: {append: nil} appends to very end
    c_ext = TaskWrap.Extension(
      [method(:add_2), id: "user.add_2", append: "task_wrap.call_task"],
      [method(:add_1), id: "user.add_1", append: nil],
    )

    wrap_runtime = {c => c_ext}

    assert_invoke Activity.new(schema), seq: "[:a, :b, :c, 2, 1]", circuit_options: {wrap_runtime: wrap_runtime}
  end

  it "populates activity[:wrap_static] and uses it at run-time" do
    merge = [
      { # Add
        insert: [Trailblazer::Activity::Adds::Insert.method(:Prepend), "task_wrap.call_task"],
        row:    TaskWrap::Pipeline::Row["user.add_1", method(:add_1)]
      },
      { # Add
        insert: [Trailblazer::Activity::Adds::Insert.method(:Append),  "task_wrap.call_task"],
        row:    TaskWrap::Pipeline::Row["user.add_2", method(:add_2)]
      }
    ]

    abc_implementation, _es = abc_implementation(a_extensions: [TaskWrap.Extension(merge: merge)])
    schema                  = Inter.(abc_intermediate, abc_implementation)

    assert_invoke Activity.new(schema), seq: "[1, :a, 2, :b, :c]"

  #@ it works nested as well

    top_implementation = {
      :a => Schema::Implementation::Task(implementing.method(:a), [Activity::Output(Activity::Right, :success)], []),
      :b => Schema::Implementation::Task(Activity.new(schema), [Activity::Output(_es, :success)], []),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                 [TaskWrap.Extension(merge: merge)]),
      "End.success" => Schema::Implementation::Task(es = implementing::Success, [Activity::Output(implementing::Success, :success)], []) # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(abc_intermediate, top_implementation)

    assert_invoke Activity.new(schema), seq: "[:a, 1, :a, 2, :b, :c, 1, :c, 2]"

  #@ it works nested plus allows {wrap_runtime}

    wrap_runtime = {c => TaskWrap::Extension.new(*merge)}

    assert_invoke Activity.new(schema), seq: "[:a, 1, :a, 2, :b, 1, :c, 2, 1, 1, :c, 2, 2]", circuit_options: {wrap_runtime: wrap_runtime}
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
      {insert: [Trailblazer::Activity::Adds::Insert.method(:Prepend), "task_wrap.call_task"], row: ["user.add_1", method(:change_start_task)]}
    ]

    outer_implementation = {
      :a => Schema::Implementation::Task(Activity.new(inner_schema), [Activity::Output(_es, :success)], [TaskWrap.Extension(merge: merge)]),
      :b => Schema::Implementation::Task(Activity.new(inner_schema), [Activity::Output(_es, :success)], []),
      :c => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],      []),
      "End.success" => Schema::Implementation::Task(es = implementing::Success, [Activity::Output(implementing::Success, :success)], []) # DISCUSS: End has one Output, signal is itself?
    }

    outer_schema = Inter.(outer_intermediate, outer_implementation)

    assert_invoke Activity.new(outer_schema), seq: "[:b, :c, :a, :b, :c, :c]", start_at: implementing.method(:b)
  end

  def change_start_task(wrap_ctx, original_args)
    (ctx, flow_options), circuit_options = original_args

    circuit_options = circuit_options.merge(start_task: ctx[:start_at])
    original_args   = [[ctx, flow_options], circuit_options]

    return wrap_ctx, original_args # yay to mutable state. not.
  end

  it "deprecates Pipeline.method(:insert) and friends" do
    merge = nil
    out, err = capture_io do
      merge = [
        [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
        [TaskWrap::Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]]
      ]
    end

  #= we get deprecation warnings for {Pipeline.insert}
    assert_equal err, %{[Trailblazer] Using `Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_before)` is deprecated.
Please use the new API: #FIXME!!!
[Trailblazer] Using `Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_after)` is deprecated.
Please use the new API: #FIXME!!!
}

    ext = nil
    out, err = capture_io do
      ext = TaskWrap.Extension(merge: merge)
    end

    assert_equal err, %{[Trailblazer] You are using the old API for taskWrap extensions.
Please update to the new TaskWrap.Extension() API: # FIXME !!!!!
}

    abc_implementation, _ = abc_implementation(a_extensions: [ext])
    schema                = Inter.(abc_intermediate, abc_implementation)

    assert_invoke(Activity.new(schema), seq: "[1, :a, 2, :b, :c]")

  #@ deprecation also works for Extension.new() (formerly {Pipeline::Merge.new})
    wrap_runtime = {abc_implementation[:c].circuit_task => TaskWrap::Extension.new(*merge)}

    abc_implementation, _ = abc_implementation() # no extensions via wrap_static.
    schema                = Inter.(abc_intermediate, abc_implementation)

    assert_invoke(Activity.new(schema), seq: "[:a, :b, 1, :c, 2]", circuit_options: {wrap_runtime: wrap_runtime})

  #@ using {Pipeline::Merge.new} also gets deprecated
    ext = nil
    out, err = capture_io do
      wrap_runtime = {abc_implementation[:c].circuit_task => TaskWrap::Pipeline::Merge.new(*merge)}
    end

    assert_equal err, %{[Trailblazer] Using `Trailblazer::Activity::TaskWrap::Pipeline::Merge.new` is deprecated.
Please use the new TaskWrap.Extension() API: #FIXME!!!
[Trailblazer] You are using the old API for taskWrap extensions.
Please update to the new TaskWrap.Extension() API: # FIXME !!!!!
}

    assert_invoke(Activity.new(schema), seq: "[:a, :b, 1, :c, 2]", circuit_options: {wrap_runtime: wrap_runtime})
  end
end
