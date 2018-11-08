require "test_helper"

class RailwayTest < Minitest::Spec
  it "accepts Railway as a builder" do
    activity = Module.new do
      extend Activity::Railway()
      step task: T.def_task(:a)
      step task: T.def_task(:b)
      fail task: T.def_task(:c)
    end

    Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
    end

  describe "#pass" do
    it "accepts Railway as a builder" do
      activity = Module.new do
        extend Activity::Railway()
        step task: T.def_task(:a)
        pass task: T.def_task(:b)
        fail task: T.def_task(:c)
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:failure>
 {Trailblazer::Activity::Left} => #<End/:failure>
#<End/:success>

#<End/:failure>
}
    end
  end

  describe ":track_end and :failure_end" do
    it "allows to define custom End instance" do
      class MyFail; end
      class MySuccess; end

      activity = Module.new do
        extend Activity::Railway( track_end: MySuccess, failure_end: MyFail )

        step task: T.def_task(:a)
      end

      Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => RailwayTest::MySuccess
 {Trailblazer::Activity::Left} => RailwayTest::MyFail
RailwayTest::MySuccess

RailwayTest::MyFail
}
    end
  end


    # normalizer
end
