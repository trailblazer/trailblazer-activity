require "test_helper"

class RailwayTest < Minitest::Spec
  describe ":Railway" do
    it "accepts Railway as a builder" do
      activity = Module.new do
        extend Activity[ Activity::Railway ]
        step task: T.def_task(:a)
        step task: T.def_task(:a)
        fail task: T.def_task(:a)
      end

      Cct(activity.decompose.first).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Right} => ActivityTest::B
 {Trailblazer::Activity::Left} => ActivityTest::C
ActivityTest::B
 {Trailblazer::Activity::Left} => ActivityTest::C
 {Trailblazer::Activity::Right} => #<End:success/:success>
ActivityTest::C
 {Trailblazer::Activity::Right} => #<End:failure/:failure>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
#<End:success/:success>

#<End:failure/:failure>
}
    end


    # normalizer
  end
end
