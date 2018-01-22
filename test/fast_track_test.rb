require "test_helper"

class FastTrackTest < Minitest::Spec
  def assert_main(activity, expected)
    Cct(activity.decompose[:circuit]).must_equal %{
#<Start:default/nil>#{expected}#<End:success/:success>

#<End:failure/:failure>

#<End:pass_fast/:pass_fast>

#<End:fail_fast/:fail_fast>
}
  end

  describe ":fail_fast" do
    it "builder API, what we use in Operation" do
      activity = Module.new do
        extend Activity::FastTrack( track_color: :pink, failure_color: :black )

        step task: T.def_task(:a), fail_fast: true # these options we WANT built by Operation (task, id, plus_poles)
        step task: T.def_task(:b)
        fail task: T.def_task(:c)
        pass task: T.def_task(:d)
      end

      Cct(activity.decompose[:circuit]).must_equal %{
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
        extend Activity::FastTrack()

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

  describe ":fail_fast" do
    it "adds pole" do
      activity = Module.new do
        extend Activity::FastTrack()

        step task: T.def_task(:a), fail_fast: true
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End:success/:success>
 {Trailblazer::Activity::Left} => #<End:fail_fast/:fail_fast>
}
    end
  end

  describe ":fast_track" do
    it "adds pole" do
      activity = Module.new do
        extend Activity::FastTrack()

        step task: T.def_task(:a), fast_track: true
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End:success/:success>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
 {Trailblazer::Activity::Magnetic::Builder::FastTrack::PassFast} => #<End:pass_fast/:pass_fast>
 {Trailblazer::Activity::Magnetic::Builder::FastTrack::FailFast} => #<End:fail_fast/:fail_fast>
}
    end

    it "allows additional signals via :plus_poles" do
      plus_poles = plus_poles_for( Signal => :success, "Another" => :failure, "Pff" => :pass_fast )

      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), plus_poles: plus_poles, fast_track: true
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Signal} => #<End:success/:success>
 {Another} => #<End:failure/:failure>
 {Pff} => #<End:pass_fast/:pass_fast>
 {Trailblazer::Activity::Magnetic::Builder::FastTrack::FailFast} => #<End:fail_fast/:fail_fast>
}
    end
  end

  describe ":plus_poles" do
    it "when :plus_poles are given, it uses the passed signals" do
      plus_poles = plus_poles_for( Signal => :success, "Another" => :failure )

      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), plus_poles: plus_poles, pass_fast: true
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Another} => #<End:failure/:failure>
 {Signal} => #<End:pass_fast/:pass_fast>
}
    end

    it "allows additional signals via :plus_poles" do
      plus_poles = plus_poles_for( Signal => :success, "Another" => :failure, "Pff" => :pass_fast )

      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), plus_poles: plus_poles, pass_fast: true
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Another} => #<End:failure/:failure>
 {Signal} => #<End:pass_fast/:pass_fast>
 {Pff} => #<End:pass_fast/:pass_fast>
}
    end

    it "allows additional signals via :plus_poles without :fast_track options" do
      plus_poles = plus_poles_for( Signal => :success, "Another" => :failure, "Pff" => :pass_fast )

      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), plus_poles: plus_poles
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Signal} => #<End:success/:success>
 {Another} => #<End:failure/:failure>
 {Pff} => #<End:pass_fast/:pass_fast>
}
    end

    it "allows additional connections via :plus_poles" do
      plus_poles = plus_poles_for( Signal => :success, "Another" => :failure, "Exception!" => :exception )

      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), plus_poles: plus_poles, Output(:failure) => Activity.End(:failed), Output(:exception) => Activity.End(:exceptioned)
      end

      Cct(activity.decompose[:circuit]).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Signal} => #<End:success/:success>
 {Another} => #<End:failed/:failed>
 {Exception!} => #<End:exceptioned/:exceptioned>
#<End:success/:success>

#<End:failure/:failure>

#<End:pass_fast/:pass_fast>

#<End:fail_fast/:fail_fast>

#<End:failed/:failed>

#<End:exceptioned/:exceptioned>
}
    end
  end

  describe ":magnetic_to" do
    it "allows overriding :magnetic_to" do
      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), magnetic_to: []
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End:success/:success>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
}
    end
  end

  describe "Output()" do
    it "allows reconnecting" do
      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), id: "a"
        step task: T.def_task(:b), Output(:success) => "a"
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
}
    end
  end

  describe "Output() => End()" do
    it "allows reconnecting" do
      activity = Module.new do
        extend Activity::FastTrack()
        step task: T.def_task(:a), id: "a"
        step task: T.def_task(:b), Output(:success) => "a", Output("Signal", :exception) => End(:exceptional, :exceptional)
      end

      Cct(activity.decompose[:circuit]).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
 {Signal} => #<End:exceptional/:exceptional>
#<End:success/:success>

#<End:failure/:failure>

#<End:pass_fast/:pass_fast>

#<End:fail_fast/:fail_fast>

#<End:exceptional/:exceptional>
}
    end
  end

  describe "pass_fast_end: and fail_fast_end:" do
    class MyFail; end
    class MySuccess; end
    class MyPassFast; end
    class MyFailFast; end

    it "allows custom ends" do
      activity = Module.new do
        extend Activity::FastTrack( track_end: MySuccess, failure_end: MyFail, pass_fast_end: MyPassFast, fail_fast_end: MyFailFast )

        step task: T.def_task(:a)
      end

      Cct(activity.decompose[:circuit]).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => FastTrackTest::MySuccess
 {Trailblazer::Activity::Left} => FastTrackTest::MyFail
FastTrackTest::MySuccess

FastTrackTest::MyFail

FastTrackTest::MyPassFast

FastTrackTest::MyFailFast
}
    end
  end

  describe "sequence_options" do
    it "accepts :before and :group" do
      activity = Module.new do
        extend Activity::FastTrack()

        step task: T.def_task(:a), id: "a"
        step task: T.def_task(:b), before: "a"
        step task: T.def_task(:c), group:  :start
      end

      assert_main activity, %{
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End:success/:success>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
}
    end
  end
end
