require "test_helper"

class PathTest < Minitest::Spec


   # Activity.plan( track_color: :pink )
  it "accepts :track_color" do
    activity = Module.new do
      extend Activity[ Activity::Path, track_color: :"track_9" ]

      task task: T.def_task(:a), id: "report_invalid_result"
      task task: T.def_task(:b), id: "log_invalid_result"#, Output(Right, :success) => End("End.invalid_result", :invalid_result)
    end

    process, outputs, adds = activity.decompose

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End:track_9/:success>
#<End:track_9/:success>
}

    SEQ(adds).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> #<Method: #<Module:0x>.a>
 (success)/Right ==> :track_9
 (failure)/Left ==> nil
[:track_9] ==> #<Method: #<Module:0x>.b>
 (success)/Right ==> :track_9
 (failure)/Left ==> nil
[:track_9] ==> #<End:track_9/:success>
 []
}
  end

  it "accepts :track_color and an explicit End" do
    activity = Module.new do
      extend Activity[ Activity::Path, track_color: :"track_9" ]

      task task: T.def_task(:a)
      task task: T.def_task(:b), id: "//b", Output(Activity::Right, :success) => End("End.invalid_result", :invalid_result)
    end

    process, outputs, adds = activity.decompose

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End:End.invalid_result/:invalid_result>
#<End:track_9/:success>

#<End:End.invalid_result/:invalid_result>
}

    SEQ(adds).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> #<Method: #<Module:0x>.a>
 (success)/Right ==> :track_9
 (failure)/Left ==> nil
[:track_9] ==> #<Method: #<Module:0x>.b>
 (success)/Right ==> "//b-Trailblazer::Activity::Right"
 (failure)/Left ==> nil
[:track_9] ==> #<End:track_9/:success>
 []
["//b-Trailblazer::Activity::Right"] ==> #<End:End.invalid_result/:invalid_result>
 []
}
  end

  describe "Path()" do
    it "accepts Path()" do
      activity = Module.new do
        extend Activity[ Activity::Path ]

        task task: T.def_task(:a)
        task task: T.def_task(:b), id: "//b", Output(Activity::Left, :failure) => Path() do
          task task: T.def_task(:c)
          task task: T.def_task(:d)
        end
      end

      process, outputs, adds = activity.decompose

      Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End:track_0./:success>
#<End:success/:success>

#<End:track_0./:success>
}

      SEQ(adds).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> #<Method: #<Module:0x>.a>
 (success)/Right ==> :success
 (failure)/Left ==> nil
[:success] ==> #<Method: #<Module:0x>.b>
 (success)/Right ==> :success
 (failure)/Left ==> \"track_0.\"
["track_0."] ==> #<Method: #<Module:0x>.c>
 (success)/Right ==> "track_0."
 (failure)/Left ==> nil
["track_0."] ==> #<Method: #<Module:0x>.d>
 (success)/Right ==> "track_0."
 (failure)/Left ==> nil
[:success] ==> #<End:success/:success>
 []
["track_0."] ==> #<End:track_0./:success>
 []
}
    end

    it "accepts :task_builder in Path()" do
      activity = Module.new do
        extend Activity[ Activity::Path, task_builder: ->(task) {task} ]

        task T.def_task(:a)
        task T.def_task(:b), id: "//b", Output(Activity::Left, :failure) => Path() do
          task T.def_task(:c)
          task T.def_task(:d)
        end
      end

      process, outputs, adds = activity.decompose

      Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End:track_0./:success>
#<End:success/:success>

#<End:track_0./:success>
}
    end
  end

end
