require "test_helper"

class PathTest < Minitest::Spec
  describe "#task standard interface" do
    it "standard path ends in End.success/:success" do
      activity = Module.new do
      extend Activity::Path()
        task task: T.def_task(:a)
        task task: T.def_task(:b)
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>
}
    end
  end

   # Activity.plan( track_color: :pink )
  it "accepts :track_color" do
    activity = Module.new do
      extend Activity::Path( track_color: :"track_9" )

      task task: T.def_task(:a), id: "report_invalid_result"
      task task: T.def_task(:b), id: "log_invalid_result"#, Output(Right, :success) => End("End.invalid_result", :invalid_result)
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>
}

    SEQ(activity.to_h[:adds]).must_equal %{
[] ==> #<Start/:default>
 (success)/Right ==> :track_9
[:track_9] ==> #<Method: #<Module:0x>.a>
 (success)/Right ==> :track_9
 (failure)/Left ==> :track_9
[:track_9] ==> #<Method: #<Module:0x>.b>
 (success)/Right ==> :track_9
 (failure)/Left ==> :track_9
[:track_9] ==> #<End/:success>
 []
}
  end

  it "accepts :track_color" do
    activity = Module.new do
      extend Activity::Path( track_color: :"track_9" )

      task task: T.def_task(:a)
      task task: T.def_task(:b)
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>
}
  end

  it "accepts :track_color and an explicit End" do
    activity = Module.new do
      extend Activity::Path( track_color: :"track_9" )

      task task: T.def_task(:a)
      task task: T.def_task(:b), id: "//b", Output(Activity::Right, :success) => End(:invalid_result)
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:invalid_result>
#<End/:success>

#<End/:invalid_result>
}

    SEQ(activity.to_h[:adds]).must_equal %{
[] ==> #<Start/:default>
 (success)/Right ==> :track_9
[:track_9] ==> #<Method: #<Module:0x>.a>
 (success)/Right ==> :track_9
 (failure)/Left ==> :track_9
[:track_9] ==> #<Method: #<Module:0x>.b>
 (success)/Right ==> "//b-Trailblazer::Activity::Right"
 (failure)/Left ==> :track_9
[:track_9] ==> #<End/:success>
 []
["//b-Trailblazer::Activity::Right"] ==> #<End/:invalid_result>
 []
}
  end

  it "accepts :type and :magnetic_to" do
    activity = Module.new do
      extend Activity::Path()

      task task: T.def_task(:a), id: "A"
      _end task: T.def_task(:b), id: "B"
      task task: T.def_task(:c), id: "C", magnetic_to: [] # start event
      _end task: T.def_task(:d), id: "D"
      task task: T.def_task(:e), id: "E", magnetic_to: [] # start event
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>

#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.d>

#<Method: #<Module:0x>.e>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>
}
  end

  it "accepts :normalizer" do
    extended_plus_poles = Activity::Magnetic::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => nil,
      Activity.Output(Activity::Left, :exception)          => nil,
      )

    normalizer = ->(task, options) { [ task, { plus_poles: extended_plus_poles }, options, {}, {} ] }

    activity = Module.new do
      extend Activity::Path( normalizer: normalizer )

      task T.def_task(:a)
      task T.def_task(:b), Output(:exception) => Path(end_semantic: :invalid) do
        task T.def_task(:c), Output(:exception) => End(:left)
        task T.def_task(:k)#, Output(:success) => End("End.invalid_result", :invalid_result)
      end
      task T.def_task(:d) # no :id.
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.k>
 {Trailblazer::Activity::Left} => #<End/:left>
#<Method: #<Module:0x>.k>
 {Trailblazer::Activity::Right} => #<End/:invalid>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:invalid>

#<End/:left>
}
  end

  describe ":normalizer" do
    it "allows injecting a normalizer on #task" do
      skip
      normalizer = ->(task, options) { [task.inspect, options, {}, {}] }

      activity = Module.new do
        extend Activity::Path()
        task task: T.def_task(:a), normalizer: normalizer
        task task: T.def_task(:b)
      end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
   {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
  }
    end
  end

  describe "sequence_options" do
    it "accepts :before and :group" do
      activity = Module.new do
        extend Activity::Path()

        task task: T.def_task(:a), id: "a"
        task task: T.def_task(:b), before: "a"
        task task: T.def_task(:c), group:  :start
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.c>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>
}
    end
  end

  describe ":track_end" do
    it "allows to define a custom End instance" do
      class MyEnd; end

      activity = Module.new do
        extend Activity::Path( track_end: MyEnd )
        task task: T.def_task(:a)
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => PathTest::MyEnd
 {Trailblazer::Activity::Left} => PathTest::MyEnd
PathTest::MyEnd
}
    end
  end

  describe ":plus_poles" do
    it "allows overriding existing outputs via semantic=>:new_color" do
      plus_poles =
        Activity::Magnetic::PlusPoles.new.merge(
          Activity.Output(Activity::Right, :success) => :success,
          Activity.Output(Activity::Left,  :failure) => :failure,
        )

      activity = Module.new do
        extend Activity::Path()
        task task: T.def_task(:a), plus_poles: plus_poles, Output(:failure) => :something_completely_different
      end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
    end
  end

  describe "Path()" do
    it "accepts Path()" do
      activity = Module.new do
        extend Activity::Path()

        task task: T.def_task(:a)
        task task: T.def_task(:b), id: "//b", Output(Activity::Left, :failure) => Path() do
          task task: T.def_task(:c)
          task task: T.def_task(:d)
        end
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/"track_0.">
 {Trailblazer::Activity::Left} => #<End/"track_0.">
#<End/:success>

#<End/"track_0.">
}

      SEQ(activity.to_h[:adds]).must_equal %{
[] ==> #<Start/:default>
 (success)/Right ==> :success
[:success] ==> #<Method: #<Module:0x>.a>
 (success)/Right ==> :success
 (failure)/Left ==> :success
[:success] ==> #<Method: #<Module:0x>.b>
 (success)/Right ==> :success
 (failure)/Left ==> \"track_0.\"
["track_0."] ==> #<Method: #<Module:0x>.c>
 (success)/Right ==> "track_0."
 (failure)/Left ==> "track_0."
["track_0."] ==> #<Method: #<Module:0x>.d>
 (success)/Right ==> "track_0."
 (failure)/Left ==> "track_0."
[:success] ==> #<End/:success>
 []
["track_0."] ==> #<End/"track_0.">
 []
}
    end

    it "accepts :task_builder in Path()" do
      activity = Module.new do
        extend Activity::Path( task_builder: ->(task) {task} )

        task T.def_task(:a)
        task T.def_task(:b), id: "//b", Output(Activity::Left, :failure) => Path() do
          task T.def_task(:c)
          task T.def_task(:d)
        end
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:success>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/"track_0.">
 {Trailblazer::Activity::Left} => #<End/"track_0.">
#<End/:success>

#<End/"track_0.">
}
    end

    it "accepts :end_semantic" do
      activity = Module.new do
        extend Activity::Path()

        task task: T.def_task(:b), Output(Activity::Left, :failure) => Path(end_semantic: :invalid) do
          task task: T.def_task(:c)
        end
        task task: T.def_task(:d)
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<End/:invalid>
 {Trailblazer::Activity::Left} => #<End/:invalid>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>

#<End/:invalid>
}
    end

    it "allows circular in the nested block" do
      activity = Module.new do
        extend Activity::Path()

        task task: T.def_task(:a), id: "extract",  Output(Activity::Left, :failure) => End(:key_not_found)
        task task: T.def_task(:b), id: "validate", Output(Activity::Left, :failure) => Path() do
          task task: T.def_task(:c)
          task task: T.def_task(:d), Output(:success) => "extract" # go back to J{extract}.
        end
        task task: T.def_task(:e)
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:key_not_found>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.e>
#<Method: #<Module:0x>.c>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Left} => #<Method: #<Module:0x>.d>
#<Method: #<Module:0x>.d>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/\"track_0.\">
#<Method: #<Module:0x>.e>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:success>
#<End/:success>

#<End/:key_not_found>

#<End/"track_0.">
}
    end
  end

  describe "Output()" do
    it "creates an output when passed a tuple" do
      activity = Module.new do
        extend Activity::Path( track_color: :"track_9" )

        task task: T.def_task(:a), Output(Activity::Right, :success) => End(:invalid_result)
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:invalid_result>
#<End/:success>

#<End/:invalid_result>
}
    end

    it "finds the correct Output when it's only Output(:semantic)" do
      activity = Module.new do
        extend Activity::Path( track_color: :"track_9" )

        task task: T.def_task(:a), Output(:success) => End(:invalid_result)
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Left} => #<End/:success>
 {Trailblazer::Activity::Right} => #<End/:invalid_result>
#<End/:success>

#<End/:invalid_result>
}
    end

    it "finds the correct Output with Output(:semantic) and custom plus_poles" do
      activity = Module.new do
        extend Activity::Path()

        task task: T.def_task(:a), Output(:trigger) => End(:something_triggered),
          plus_poles: Activity::Magnetic::PlusPoles.new.merge(
                        Activity.Output("trigger!",      :trigger) => nil,
                        Activity.Output(Activity::Right, :success) => nil,
                      ).freeze
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<End/:success>
 {trigger!} => #<End/:something_triggered>
#<End/:success>

#<End/:something_triggered>
}
    end

    it "can build fake Railway using Output(Left)s" do
      activity = Module.new do
        extend Activity::Path( track_color: :"track_9" )
        task task: T.def_task(:a), Output(Activity::Left, :failure) => End(:key_not_found)
        task task: T.def_task(:b), Output(Activity::Left, :failure) => End(:invalid)
      end

      Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.a>
#<Method: #<Module:0x>.a>
 {Trailblazer::Activity::Right} => #<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Left} => #<End/:key_not_found>
#<Method: #<Module:0x>.b>
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:key_not_found>
#<End/:success>

#<End/:key_not_found>

#<End/:invalid>
}
    end
  end

end
