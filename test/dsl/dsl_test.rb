require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Activity::Left
  Right = Trailblazer::Activity::Right

  class A; end
  class B; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  #---
  # wiring options

  # 3 ends, 1 of 'em default.
  it do
    activity = Module.new do
      extend Activity::Path( track_color: :"track_9" )
      task task: J, id: "extract",  Output(Left, :failure) => End(:key_not_found)
      task task: K, id: "validate", Output(Left, :failure) => End(:invalid)
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityBuildTest::J
ActivityBuildTest::J
 {Trailblazer::Activity::Right} => ActivityBuildTest::K
 {Trailblazer::Activity::Left} => #<End/:key_not_found>
ActivityBuildTest::K
 {Trailblazer::Activity::Right} => #<End/:success>
 {Trailblazer::Activity::Left} => #<End/:invalid>
#<End/:success>

#<End/:key_not_found>

#<End/:invalid>
}
  end

  # Activity with 2 predefined outputs, direct 2nd one to new end
  it do
    activity = Module.new do
      extend Activity::Path( track_color: :"track_9" )

      task task: J,
        Output(Left, :trigger) => End(:triggered),
        # this comes from the Operation DSL since it knows {Activity}J
        plus_poles: Activity::Magnetic::DSL::PlusPoles.new.merge(
          Activity.Output(Activity::Left,  :trigger) => nil,
          Activity.Output(Activity::Right, :success) => nil,
        ).freeze
      task task: K
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityBuildTest::J
ActivityBuildTest::J
 {Trailblazer::Activity::Right} => ActivityBuildTest::K
 {Trailblazer::Activity::Left} => #<End/:triggered>
ActivityBuildTest::K
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:triggered>
}
  end


  it "raises exception when referencing non-existant semantic" do
    exception = assert_raises do
      activity = Module.new do
        extend Activity::Path()

        task J,
          Output(:does_absolutely_not_exist) => End(:triggered)
      end
    end

    exception.message.must_equal "Couldn't find existing output for `:does_absolutely_not_exist`."
  end

  # only PlusPole goes straight to IDed end.
  it "connects task to End" do
    activity = Module.new do
      extend Activity::Path( track_color: :"track_9" )
      task task: J, id: "confused", Output(Right, :success) => "End.track_9"
      task task: K, id: "normal"
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityBuildTest::J
ActivityBuildTest::J
 {Trailblazer::Activity::Right} => #<End/:success>
ActivityBuildTest::K
 {Trailblazer::Activity::Right} => ActivityBuildTest::K
#<End/:success>
}
  end


  # circulars, etc.
  it do
    activity = Module.new do
      extend Activity::Path()

      # circular
      task task: A, id: "inquiry_create", Output(Activity::Left, :failure) => Path() do
        task task: B, id: "suspend_for_correct", Output(:success) => "inquiry_create"#, plus_poles: binary_plus_poles
      end

      task task: G, id: "receive_process_id"
      # task task: Task(), id: :suspend_wait_for_result

      task task: I, id: :process_result, Output(Activity::Left, :failure) => Path(end_semantic: :invalid_result) do
        task task: J, id: "report_invalid_result"
        task task: K, id: "log_invalid_result"#, Output(:success) => End("End.invalid_result", :invalid_result)
      end

      task task: L, id: :notify_clerk#, Output(Right, :success) => :success
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityBuildTest::A
ActivityBuildTest::A
 {Trailblazer::Activity::Left} => ActivityBuildTest::B
 {Trailblazer::Activity::Right} => ActivityBuildTest::G
ActivityBuildTest::B
 {Trailblazer::Activity::Right} => ActivityBuildTest::A
ActivityBuildTest::G
 {Trailblazer::Activity::Right} => ActivityBuildTest::I
ActivityBuildTest::I
 {Trailblazer::Activity::Left} => ActivityBuildTest::J
 {Trailblazer::Activity::Right} => ActivityBuildTest::L
ActivityBuildTest::J
 {Trailblazer::Activity::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Activity::Right} => #<End/:invalid_result>
ActivityBuildTest::L
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/"track_0.">

#<End/:invalid_result>
}

    Ends(activity.to_h[:circuit]).must_equal %{[#<End/:success>,#<End/:invalid_result>]}
  end

  it "::build - THIS IS NOT THE GRAPH YOU MIGHT WANT " do # FIXME: what were we (or I, haha) testing in here?
    activity = Module.new do
      extend Activity::Path()

      task task: A, id: "inquiry_create", Output(Left, :failure) => "suspend_for_correct", Output(:success) => "receive_process_id"
      task task: B, id: "suspend_for_correct", Output(:failure) => "inquiry_create"

      task task: G, id: "receive_process_id", magnetic_to: []

      task task: I, id: :process_result, Output(Left, :failure) => Path(end_semantic: :invalid_resulto) do
        task task: J, id: "report_invalid_result"
        # task task: K, id: "log_invalid_result", Output(:success) => color
        task task: K, id: "log_invalid_result", Output(:success) => End(:invalid_result)
      end

      task task: L, id: :notify_clerk#, Output(Right, :success) => :success
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => ActivityBuildTest::A
ActivityBuildTest::A
 {Trailblazer::Activity::Left} => ActivityBuildTest::B
 {Trailblazer::Activity::Right} => ActivityBuildTest::G
ActivityBuildTest::B
 {Trailblazer::Activity::Right} => ActivityBuildTest::B
 {Trailblazer::Activity::Left} => ActivityBuildTest::A
ActivityBuildTest::G
 {Trailblazer::Activity::Right} => ActivityBuildTest::I
ActivityBuildTest::I
 {Trailblazer::Activity::Left} => ActivityBuildTest::J
 {Trailblazer::Activity::Right} => ActivityBuildTest::L
ActivityBuildTest::J
 {Trailblazer::Activity::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Activity::Right} => #<End/:invalid_result>
ActivityBuildTest::L
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:invalid_resulto>

#<End/:invalid_result>
}
  end
end


