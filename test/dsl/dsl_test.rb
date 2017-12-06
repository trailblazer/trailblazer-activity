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

  # 3 ends, 1 of 'em default.
  it do
    seq, adds = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)
      task K, id: "validate", Output(Left, :failure) => End("End.invalid", :invalid)
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> "extract-Trailblazer::Activity::Left"
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
 (failure)/Left ==> "validate-Trailblazer::Activity::Left"
[:track_9] ==> #<End:track_9/:success>
 []
["extract-Trailblazer::Activity::Left"] ==> #<End:End.extract.key_not_found/:key_not_found>
 []
["validate-Trailblazer::Activity::Left"] ==> #<End:End.invalid/:invalid>
 []
}
  end

  # straight path with different name for :success.
  it do
    seq, adds = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "first"
      task K, id: "last"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9/:success>
 []
}
  end

  # some new Output
  it do
    seq, adds = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused", Output(Left, :failure) => :success__
      task K, id: "normal"
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> :success__
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9/:success>
 []
}
  end

  it "Output(Left, :failure) allows to skip the additional :plus_poles definition" do
    seq, adds = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused", Output(Left, :failure) => :"track_9"
      task K, id: "normal"
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9/:success>
 []
}
  end

  # Activity with 2 predefined outputs, direct 2nd one to new end
  it do
    seq, adds = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused",
        Output(Left, :trigger) => End("End.trigger", :triggered),
        # this comes from the Operation DSL since it knows {Activity}J
        plus_poles: Activity::Magnetic::DSL::PlusPoles.new.merge(
          Activity.Output(Activity::Left,  :trigger) => nil,
          Activity.Output(Activity::Right, :success) => nil,
        ).freeze
      task K, id: "normal"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "confused-Trailblazer::Activity::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9/:success>
 []
["confused-Trailblazer::Activity::Left"] ==> #<End:End.trigger/:triggered>
 []
}
  end

  # test Output(:semantic)
  # Activity with 2 predefined outputs, direct 2nd one to new end without Output
  it do
    seq, adds = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused",
        Output(:trigger) => End("End.trigger", :triggered),
        # this comes from the Operation DSL since it knows {Activity}J
        plus_poles: Activity::Magnetic::DSL::PlusPoles.new.merge(
          Activity.Output(Activity::Left,  :trigger) => nil,
          Activity.Output(Activity::Right, :success) => nil,
        ).freeze
      task K, id: "normal"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "confused-Trailblazer::Activity::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9/:success>
 []
["confused-Trailblazer::Activity::Left"] ==> #<End:End.trigger/:triggered>
 []
}
  end

  it "raises exception when referencing non-existant semantic" do
    exception = assert_raises do
      Activity::Process.draft do
        task J,
          Output(:does_absolutely_not_exist) => End("End.trigger", :triggered)
      end
    end

    exception.message.must_equal "Couldn't find existing output for `:does_absolutely_not_exist`."
  end

  # only PlusPole goes straight to IDed end.
  it do
    seq, adds = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused", Output(Right, :success) => "End.track_9"
      task K, id: "normal"
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> "Trailblazer::Activity::Right-End.track_9"
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9, "Trailblazer::Activity::Right-End.track_9"] ==> #<End:track_9/:success>
 []
}
  end


  # circulars, etc.
  it do
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => nil,
      Activity.Output(Activity::Left, :failure) => nil )

    tripletts, adds = Activity::Process.draft do
      # circular
      task A, id: "inquiry_create", Output(Left, :failure) => Path() do
        task B, id: "suspend_for_correct", Output(:success) => "inquiry_create"#, plus_poles: binary_plus_poles
      end

      task G, id: "receive_process_id"
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Left, :failure) => Path(end_semantic: :invalid_result) do
        task J, id: "report_invalid_result"
        # task K, id: "log_invalid_result", Output(:success) => color
        task K, id: "log_invalid_result"#, Output(:success) => End("End.invalid_result", :invalid_result)
      end

      task L, id: :notify_clerk#, Output(Right, :success) => :success
    end

    process, _ = Activity::Magnetic::Builder.finalize( adds )

    Cct(process).must_equal %{
#<Start:default/nil>
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
 {Trailblazer::Activity::Right} => #<End:track_0./:invalid_result>
ActivityBuildTest::L
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>

#<End:track_0./:success>

#<End:track_0./:invalid_result>
}

    Ends(process).must_equal %{[#<End:success/:success>,#<End:track_0./:invalid_result>]}
  end

  it "::build - THIS IS NOT THE GRAPH YOU MIGHT WANT " do # FIXME: what were we (or I, haha) testing in here?
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => nil,
      Activity.Output(Activity::Left, :failure) => nil )

    seq, adds = Activity::Process.draft do
      task A, id: "inquiry_create", Output(Left, :failure) => "suspend_for_correct", Output(:success) => "receive_process_id"
      task B, id: "suspend_for_correct", Output(:failure) => "inquiry_create", plus_poles: binary_plus_poles

      task G, id: "receive_process_id"
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Left, :failure) => Path(end_semantic: :invalid_resulto) do
        task J, id: "report_invalid_result"
        # task K, id: "log_invalid_result", Output(:success) => color
        task K, id: "log_invalid_result", Output(:success) => End("End.invalid_result", :invalid_result)
      end

      task L, id: :notify_clerk#, Output(Right, :success) => :success
    end

    process, _ = Activity::Magnetic::Builder::Path.finalize( adds )

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => ActivityBuildTest::A
ActivityBuildTest::A
 {Trailblazer::Activity::Left} => ActivityBuildTest::B
 {Trailblazer::Activity::Right} => ActivityBuildTest::G
ActivityBuildTest::B
 {Trailblazer::Activity::Right} => ActivityBuildTest::B
 {Trailblazer::Activity::Left} => ActivityBuildTest::A
ActivityBuildTest::G
 {Trailblazer::Activity::Right} => ActivityBuildTest::G
ActivityBuildTest::I
 {Trailblazer::Activity::Right} => ActivityBuildTest::I
 {Trailblazer::Activity::Left} => ActivityBuildTest::J
ActivityBuildTest::J
 {Trailblazer::Activity::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Activity::Right} => #<End:End.invalid_result/:invalid_result>
ActivityBuildTest::L
 {Trailblazer::Activity::Right} => ActivityBuildTest::L
#<End:success/:success>

#<End:track_0./:invalid_resulto>

#<End:End.invalid_result/:invalid_result>
}
  end
end


