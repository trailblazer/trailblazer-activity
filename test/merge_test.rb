require "test_helper"

class MergeTest < Minitest::Spec
  Activity = Trailblazer::Activity

  it do
    activity = Module.new do
      extend Activity[ Activity::Path ]

      task task: :a, id: "a"
    end

    merged = Module.new do
      extend Activity::Path::Plan

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
end
