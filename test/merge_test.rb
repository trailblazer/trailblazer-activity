require "test_helper"

class MergeTest < Minitest::Spec
  it do
    activity = Module.new do
      extend Activity[ Activity::Path ]

      task task: :a, id: "a"
    end

    merged = Module.new do
      extend Activity[ Activity::Path::Plan ]

      task task: :b, before: "a"
      task task: :c
    end

    # pp activity+merged
    _activity = Activity::Path::Plan.merge!(activity, merged)

    # the existing activity gets extended.
    activity.must_equal _activity

    Cct(activity.decompose.first).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => :b
:b
 {Trailblazer::Activity::Right} => :a
:a
 {Trailblazer::Activity::Right} => :c
:c
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}
  end

  describe "Activity.merge" do
    it "creates a new module without mutating shared state" do
      activity = Module.new do
        extend Activity[ Activity::Path ]

        task task: :a, id: "a"
      end

      plan = Module.new do
        extend Activity[ Activity::Path::Plan ]

        task task: :b, before: "a"
        task task: :c
      end

      merged = Activity::Path::Plan.merge(activity, plan)

      # activity still has one step
      Cct(activity.decompose.first).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => :a
:a
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}

      Cct(merged.decompose.first).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => :b
:b
 {Trailblazer::Activity::Right} => :a
:a
 {Trailblazer::Activity::Right} => :c
:c
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}
    end

    # TODO: test @options.frozen?
  end
end
