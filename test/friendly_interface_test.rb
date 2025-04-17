require "test_helper"

# High-level interface to ADDS.
    # TODO: merge with {task_wrap_test.rb}.
class FriendlyInterfaceTest < Minitest::Spec
  it "what" do
    # create new task_wrap with empty original array.
    ext = TaskWrap.Extension(
      [Object, id: "task_wrap.call_task", append: nil]
    )

    task_wrap = ext.([])

    assert_equal task_wrap.inspect, %([["task_wrap.call_task", Object]])

    ext = TaskWrap.Extension(
      [Object, id: "task_wrap.call_task", replace: "task_wrap.call_task"]
    )

    task_wrap = ext.(task_wrap)

    assert_equal task_wrap.inspect, %([["task_wrap.call_task", Object]])

    ext = TaskWrap.Extension(
      [Module, id: "my.before", prepend: "task_wrap.call_task"],
      [Class, id: "my.after", append: "task_wrap.call_task"],
    )

    task_wrap = ext.(task_wrap)

    assert_equal task_wrap.inspect, %([["my.before", Module], ["task_wrap.call_task", Object], ["my.after", Class]])

    ext = TaskWrap.Extension(
      [String, id: "my.prepend", prepend: nil],
      [Float, id: "my.append", append: nil],
    )

    task_wrap = ext.(task_wrap)

    assert_equal task_wrap.inspect, %([["my.prepend", String], ["my.before", Module], ["task_wrap.call_task", Object], ["my.after", Class], ["my.append", Float]])
  end
end
