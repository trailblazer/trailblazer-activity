require "test_helper"

# High-level interface to ADDS.
    # TODO: merge with {task_wrap_test.rb}.
class FriendlyInterfaceTest < Minitest::Spec
  it "provides several insertion strategies" do
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

  it "allows using step IDs from earlier inserted steps" do
    ext = TaskWrap.Extension(
      [Object, id: "task_wrap.call_task", append: nil],
      [Module, id: "my.object", append: "task_wrap.call_task"],
      [Class, id: "my.class", prepend: "my.object"], # my.object is the step from above.
    )

    task_wrap = ext.([])

    assert_equal task_wrap.inspect, %([["task_wrap.call_task", Object], ["my.class", Class], ["my.object", Module]])
  end

   describe "Extension" do
    def add_1(wrap_ctx, original_args)
      ctx, = original_args[0]
      ctx[:seq] << 1
      return wrap_ctx, original_args # yay to mutable state. not.
    end

    it "deprecates {TaskWrap.WrapStatic}" do
      adds = [
        [method(:add_1), id: "user.add_1", prepend: "task_wrap.call_task"],
        # [method(:add_2), id: "user.add_2", append:  "task_wrap.call_task"],
      ]

      ext = nil
      _, warning = capture_io do
        ext = TaskWrap::Extension.WrapStatic(*adds)
      end
      line_number_for_binary = __LINE__ - 2

      # lines = warning.split("\n")
      # lines[0] = lines[0][0..-5]+"." if lines[0] =~ /\d-\d+-\d/
      # warning = lines.join("\n")

      assert_equal warning, %{[Trailblazer] #{File.realpath(__FILE__)}:#{line_number_for_binary} Using `TaskWrap::Extension.WrapStatic()` is deprecated. Please use `TaskWrap.Extension()`.\n}
      assert_equal ext.class, Trailblazer::Activity::TaskWrap::Extension
      # DISCUSS: should we test if the extension is correct?
    end

    it "{Extension#call} accepts **options" do
      adds = [
        [Object, id: "user.add_1", prepend: nil],
      ]

      ext = TaskWrap::Extension(*adds)

      task_wrap = ext.([], some: :options)

      assert_equal task_wrap.inspect, %([["user.add_1", Object]])
    end
  end
end
