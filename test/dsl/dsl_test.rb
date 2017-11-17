require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right


  class A; end
  class B; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end




  # 3 ends, 1 of 'em default.
  it do
    seq = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)
      task K, id: "validate", Output(Left, :failure) => End("End.invalid", :invalid)
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> "extract-Trailblazer::Circuit::Left"
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
 (failure)/Left ==> "validate-Trailblazer::Circuit::Left"
[:track_9] ==> #<End:track_9/:success>
 []
["extract-Trailblazer::Circuit::Left"] ==> #<End:End.extract.key_not_found/:key_not_found>
 []
["validate-Trailblazer::Circuit::Left"] ==> #<End:End.invalid/:invalid>
 []
}
  end

  # straight path with different name for :success.
  it do
    seq = Activity::Process.draft(track_color: :"track_9") do
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
    seq = Activity::Process.draft(track_color: :"track_9") do
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
    seq = Activity::Process.draft(track_color: :"track_9") do
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
    seq = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused",
        Output(Left, :trigger) => End("End.trigger", :triggered),
        # this comes from the Operation DSL since it knows {Activity}J
        plus_poles: Activity::Magnetic::DSL::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Left,  :trigger) => nil,
          Activity::Magnetic.Output(Circuit::Right, :success) => nil,
        ).freeze
      task K, id: "normal"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "confused-Trailblazer::Circuit::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9/:success>
 []
["confused-Trailblazer::Circuit::Left"] ==> #<End:End.trigger/:triggered>
 []
}
  end

  # test Output(:semantic)
  # Activity with 2 predefined outputs, direct 2nd one to new end without Output
  it do
    seq = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused",
        Output(:trigger) => End("End.trigger", :triggered),
        # this comes from the Operation DSL since it knows {Activity}J
        plus_poles: Activity::Magnetic::DSL::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Left,  :trigger) => nil,
          Activity::Magnetic.Output(Circuit::Right, :success) => nil,
        ).freeze
      task K, id: "normal"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "confused-Trailblazer::Circuit::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9/:success>
 []
["confused-Trailblazer::Circuit::Left"] ==> #<End:End.trigger/:triggered>
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
    seq = Activity::Process.draft(track_color: :"track_9") do
      task J, id: "confused", Output(Right, :success) => "End.track_9"
      task K, id: "normal"
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> "Trailblazer::Circuit::Right-End.track_9"
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9, "Trailblazer::Circuit::Right-End.track_9"] ==> #<End:track_9/:success>
 []
}
  end


  # circulars, etc.
  it do
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => nil,
      Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

    tripletts = Activity::Process.draft do
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

puts Seq(tripletts)

  circuit_hash = Trailblazer::Activity::Magnetic::Generate.( tripletts )

     # puts Cct(circuit_hash)
    Cct(circuit_hash).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => ActivityBuildTest::A
ActivityBuildTest::A
 {Trailblazer::Circuit::Left} => ActivityBuildTest::B
 {Trailblazer::Circuit::Right} => ActivityBuildTest::G
ActivityBuildTest::B
 {Trailblazer::Circuit::Right} => ActivityBuildTest::A
ActivityBuildTest::G
 {Trailblazer::Circuit::Right} => ActivityBuildTest::I
ActivityBuildTest::I
 {Trailblazer::Circuit::Left} => ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::L
ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Circuit::Right} => #<End:track_0./:invalid_result>
ActivityBuildTest::L
 {Trailblazer::Circuit::Right} => #<End:success/:success>
#<End:success/:success>

#<End:track_0./:success>

#<End:track_0./:invalid_result>
}
  end

  it "::build - THIS IS NOT THE GRAPH YOU MIGHT WANT " do
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => nil,
      Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

    process = Activity::Process.build do
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

    circuit_hash = process.instance_variable_get(:@circuit).to_fields.first

puts Cct(circuit_hash)
    Cct(circuit_hash).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => ActivityBuildTest::A
ActivityBuildTest::A
 {Trailblazer::Circuit::Left} => ActivityBuildTest::B
 {Trailblazer::Circuit::Right} => ActivityBuildTest::G
ActivityBuildTest::B
 {Trailblazer::Circuit::Right} => ActivityBuildTest::B
 {Trailblazer::Circuit::Left} => ActivityBuildTest::A
ActivityBuildTest::G
 {Trailblazer::Circuit::Right} => ActivityBuildTest::G
ActivityBuildTest::I
 {Trailblazer::Circuit::Right} => ActivityBuildTest::I
 {Trailblazer::Circuit::Left} => ActivityBuildTest::J
ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Circuit::Right} => #<End:End.invalid_result/:invalid_result>
ActivityBuildTest::L
 {Trailblazer::Circuit::Right} => ActivityBuildTest::L
#<End:success/:success>

#<End:track_0./:invalid_resulto>

#<End:End.invalid_result/:invalid_result>
}

    # activity.outputs.values.must_equal [:success, :invalid_resulto, :invalid_result]
  end


  it "what" do
    initial_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      Activity::Magnetic.Output("Signal A", :exception)  => :exception,
      Activity::Magnetic.Output(Circuit::Left, :failure) => :failure )

    adds = Activity::Magnetic::DSL::ProcessElement.(
      Activity::Magnetic::DSL::Alterations.new,
      G,
        id: :receive_process_id,
        strategy: [
          Activity::Magnetic::DSL::FastTrack.method(:step),
          plus_poles: initial_plus_poles,
        ],

        # existing success to new end
        Activity::Magnetic.Output(Right, :success) => Activity::Magnetic.End(:invalid_result),

        Activity::Magnetic.Output("Signal A", :exception) => Activity::Magnetic.End(:signal_a_reached),
     )

    seq = Activity::Magnetic::Builder.adds_to_tripletts(adds)

    Seq(seq).must_equal %{
[:success] ==> ActivityBuildTest::G
 (success)/Right ==> "receive_process_id-Trailblazer::Circuit::Right"
 (exception)/Signal A ==> "receive_process_id-Signal A"
 (failure)/Left ==> :failure
["receive_process_id-Trailblazer::Circuit::Right"] ==> #<End:invalid_result/:invalid_result>
 []
["receive_process_id-Signal A"] ==> #<End:signal_a_reached/:signal_a_reached>
 []
}
  end



end


