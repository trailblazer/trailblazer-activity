require "test_helper"

class IntrospectionTest < Minitest::Spec
  describe "Introspect.find_path" do
    it "#find_path" do
      nested_builder = Class.new do
        include Fixtures::NestingActivity
      end

      middle = nested_builder.new
      nesting_tasks = middle.tasks(flat_activity: flat_activity)
      middle_activity = middle.activity(tasks: nesting_tasks) # [a, [b, c]]

      top = nested_builder.new
      nesting_tasks = top.tasks(flat_activity: middle_activity)
      activity = top.activity(tasks: nesting_tasks) # [a, [a, [b, c]]]

      #@ find top-activity which returns a special Node.
      node, host_activity, graph = Trailblazer::Activity::Introspect.find_path(activity, [])
      assert_equal node.class, Trailblazer::Activity::Schema::Nodes::Attributes
      assert_equal node[:task], activity
      assert_equal host_activity, Trailblazer::Activity::TaskWrap.container_activity_for(activity)

      #@ one element path
      node, host_activity, graph = Trailblazer::Activity::Introspect.find_path(activity, ["a"])
      assert_equal node.class, Trailblazer::Activity::Schema::Nodes::Attributes
      assert_equal node[:task], Implementing.method(:a)
      assert_equal host_activity, activity

      #@ nested element
      node, host_activity, _graph = Trailblazer::Activity::Introspect.find_path(activity, ["flat_activity", "flat_activity", "b"])
      assert_equal node.class, Trailblazer::Activity::Schema::Nodes::Attributes
      assert_equal node[:task], Implementing.method(:b)
      assert_equal host_activity, flat_activity

      #@ non-existent element
      assert_nil Trailblazer::Activity::Introspect.find_path(activity, [:c])
      assert_nil Trailblazer::Activity::Introspect.find_path(activity, ["flat_activity", :c])
    end
  end

  describe "Introspect.Nodes()" do
    let(:task_map) { Trailblazer::Activity::Introspect.Nodes(flat_activity)  } # [B, C]

    it "returns Nodes that looks like a Hash" do
      assert_equal task_map.class, Trailblazer::Activity::Schema::Nodes
    end

    it "exposes #[] to find by task" do
      attributes = task_map[Implementing.method(:b)]
      assert_equal attributes.id,   "b"
      assert_equal attributes.task, Implementing.method(:b)

      #@ non-existent
      assert_nil task_map[nil]
    end

    it "exposes #fetch to find by task" do
      assert_equal task_map.fetch(Implementing.method(:b)).id, "b"

      #@ non-existent
      assert_raises KeyError do task_map.fetch(nil) end
    end

    it "accepts {:id} option" do
      attrs = Trailblazer::Activity::Introspect.Nodes(flat_activity, id: "b")

      assert_equal attrs.id, "b"
      assert_equal attrs.task, Implementing.method(:b)
    end

    it "accepts {id: nil}" do
      container_activity = Trailblazer::Activity::TaskWrap.container_activity_for(flat_activity)

      attrs = Trailblazer::Activity::Introspect.Nodes(container_activity, id: nil)

      assert_equal attrs.id, nil
      assert_equal attrs.task, flat_activity
    end

    it "accepts {:task} option" do
      attrs = Trailblazer::Activity::Introspect.Nodes(flat_activity, task: Implementing.method(:b))

      assert_equal attrs.id, "b"
      assert_equal attrs.task, Implementing.method(:b)
    end
  end
end
