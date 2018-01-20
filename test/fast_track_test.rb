require "test_helper"

class FastTrackTest < Minitest::Spec
  def assert_main(activity, expected)
    Cct(activity.decompose.first).must_equal %{
#<Start:default/nil>#{expected}#<End:success/:success>

#<End:failure/:failure>

#<End:pass_fast/:pass_fast>

#<End:fail_fast/:fail_fast>
}
  end

  describe ":fail_fast" do
    it "builder API, what we use in Operation" do
      activity = Module.new do
        extend Activity[ Activity::FastTrack, track_color: :pink, failure_color: :black ]

        step task: T.def_task(:a), fail_fast: true # these options we WANT built by Operation (task, id, plus_poles)
        step task: T.def_task(:b)
        fail task: T.def_task(:c)
        pass task: T.def_task(:d)
      end

      Cct(activity.decompose.first).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End:fail_fast/:fail_fast>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End:black/:failure>
 {Trailblazer::Activity::Left} => #<End:black/:failure>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End:pink/:success>
 {Trailblazer::Activity::Left} => #<End:pink/:success>
#<End:pink/:success>

#<End:black/:failure>

#<End:pass_fast/:pass_fast>

#<End:fail_fast/:fail_fast>
}
    end
  end

  describe ":pass_fast" do
    it "adds :pass_fast pole" do
      activity = Module.new do
        extend Activity[ Activity::FastTrack ]

        step task: T.def_task(:a), pass_fast: true
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
 {Trailblazer::Activity::Right} => #<End:pass_fast/:pass_fast>
}
    end
  end

  describe ":plus_poles" do
    it "when :plus_poles are given, it uses the passed signals" do
      plus_poles = plus_poles_for( Signal => :success, "Another" => :failure )

      activity = Module.new do
        extend Activity[ Activity::FastTrack ]
        step task: T.def_task(:a), plus_poles: plus_poles, pass_fast: true
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Another} => #<End:failure/:failure>
 {Signal} => #<End:pass_fast/:pass_fast>
}
    end
  end
end
