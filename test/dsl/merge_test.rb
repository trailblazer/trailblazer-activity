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
    process, outputs = Activity::Magnetic::Builder.merge(activity, merged)

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => :b
:b
 {Trailblazer::Circuit::Right} => :a
:a
 {Trailblazer::Circuit::Right} => :c
:c
 {Trailblazer::Circuit::Right} => #<End:success/:success>
#<End:success/:success>
}
  end
end
