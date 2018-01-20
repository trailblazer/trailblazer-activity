require "test_helper"

class MergeTest < Minitest::Spec
  Activity = Trailblazer::Activity

  it do
    activity = Activity::Magnetic::Builder::Path.plan do
      task :a, id: :a
    end

    merged = Activity::Magnetic::Builder::Path.plan do
      task :b, before: :a
      task :c
    end

    # pp activity+merged
    adds = Activity::Magnetic::Builder.merge(activity, merged)

    process, outputs = Activity::Magnetic::Builder::Finalizer.(adds)

    Cct(process).must_equal %{
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
