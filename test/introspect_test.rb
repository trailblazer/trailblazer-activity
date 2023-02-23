require "test_helper"

class IntrospectionTest < Minitest::Spec
  describe "Introspect.find_path" do
    it "#find_path" do
      b_activity = nested_activity() # [B, [B, C], E]
      activity   = nested_activity(flat_activity: b_activity, d_id: :Delete) # [B, Delete=[B, D=[B, C], E], E]

      #@ find top-activity which returns a special Node.
      node, host_activity, graph = Trailblazer::Activity::Introspect.find_path(activity, [])
      assert_equal node.class, Trailblazer::Activity::Schema::Nodes::Attributes
      assert_equal node[:task], activity
      assert_equal host_activity, Trailblazer::Activity::TaskWrap.container_activity_for(activity)

      #@ one element path
      node, host_activity, graph = Trailblazer::Activity::Introspect.find_path(activity, [:E])
      assert_equal node.class, Trailblazer::Activity::Schema::Nodes::Attributes
      assert_equal node[:task], Implementing.method(:f)
      assert_equal host_activity, activity

      #@ nested element
      node, host_activity, _graph = Trailblazer::Activity::Introspect.find_path(activity, [:Delete, :D, :C])
      assert_equal node.class, Trailblazer::Activity::Schema::Nodes::Attributes
      assert_equal node[:task], Implementing.method(:c)
      assert_equal host_activity, flat_activity

      #@ non-existent element
      assert_nil Trailblazer::Activity::Introspect.find_path(activity, [:c])
      assert_nil Trailblazer::Activity::Introspect.find_path(activity, [:Delete, :c])
    end
  end

  describe "Introspect.Nodes()" do
    let(:task_map) { Activity::Introspect.Nodes(flat_activity)  } # [B, C]

    it "returns Nodes that looks like a Hash" do
      assert_equal task_map.class, Activity::Schema::Nodes
    end

    it "exposes #[] to find by task" do
      attributes = task_map[Implementing.method(:b)]
      assert_equal attributes.id,   :B
      assert_equal attributes.task, Implementing.method(:b)

      #@ non-existent
      assert_nil task_map[nil]
    end

    it "exposes #fetch to find by task" do
      assert_equal task_map.fetch(Implementing.method(:b)).id, :B

      #@ non-existent
      assert_raises KeyError do task_map.fetch(nil) end
    end

    it "accepts {:id} option" do
      attrs = Activity::Introspect.Nodes(flat_activity, id: :B)

      assert_equal attrs.id, :B
      assert_equal attrs.task, Implementing.method(:b)
    end

    it "accepts {:task} option" do
      attrs = Activity::Introspect.Nodes(flat_activity, task: Implementing.method(:b))

      assert_equal attrs.id, :B
      assert_equal attrs.task, Implementing.method(:b)
    end
  end
end
