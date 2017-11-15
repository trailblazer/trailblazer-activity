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

  # Activity.plan( track_color: :pink )
  it "unit test" do
    block = -> do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result", Output(Right, :success) => End("End.invalid_result", :invalid_result)
    end

    seq = Activity.plan(track_color: :"track_9", &block)

    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> "log_invalid_result-Trailblazer::Circuit::Right"
[:track_9] ==> #<End:track_9>
 []
["log_invalid_result-Trailblazer::Circuit::Right"] ==> #<End:End.invalid_result>
 []
}
  end

  # 3 ends, 1 of 'em default.
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)
      task K, id: "validate", Output(Left, :failure) => End("End.invalid", :invalid)
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> "extract-Trailblazer::Circuit::Left"
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
 (failure)/Left ==> "validate-Trailblazer::Circuit::Left"
[:track_9] ==> #<End:track_9>
 []
["extract-Trailblazer::Circuit::Left"] ==> #<End:End.extract.key_not_found>
 []
["validate-Trailblazer::Circuit::Left"] ==> #<End:End.invalid>
 []
}
  end

  # straight path with different name for :success.
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "first"
      task K, id: "last"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
}
  end

  # some new Output
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "confused", Output(Left, :failure) => :success__
      task K, id: "normal"
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> :success__
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
}
  end

  it "Output(Left, :failure) allows to skip the additional :plus_poles definition" do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "confused", Output(Left, :failure) => :"track_9"
      task K, id: "normal"
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
}
  end

  # Activity with 2 predefined outputs, direct 2nd one to new end
  it do
    seq = Activity.plan(track_color: :"track_9") do
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
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "confused-Trailblazer::Circuit::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
["confused-Trailblazer::Circuit::Left"] ==> #<End:End.trigger>
 []
}
  end

  # test Output(:semantic)
  # Activity with 2 predefined outputs, direct 2nd one to new end without Output
  it do
    seq = Activity.plan(track_color: :"track_9") do
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
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "confused-Trailblazer::Circuit::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
["confused-Trailblazer::Circuit::Left"] ==> #<End:End.trigger>
 []
}
  end

  it "raises exception when referencing non-existant semantic" do
    exception = assert_raises do
      Activity.plan do
        task J,
          Output(:does_absolutely_not_exist) => End("End.trigger", :triggered)
      end
    end

    exception.message.must_equal "Couldn't find existing output for `:does_absolutely_not_exist`."
  end

  # only PlusPole goes straight to IDed end.
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "confused", Output(Right, :success) => "End.track_9"
      task K, id: "normal"
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> "Trailblazer::Circuit::Right-End.track_9"
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9, "Trailblazer::Circuit::Right-End.track_9"] ==> #<End:track_9>
 []
}
  end


  # circulars, etc.
  it do
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => nil,
      Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

    tripletts = Activity.plan do
      task A, id: "inquiry_create", Output(Left, :failure) => "suspend_for_correct"
        task B, id: "suspend_for_correct", Output(:failure) => "inquiry_create", plus_poles: binary_plus_poles

      task G, id: :receive_process_id
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Left, :failure) => -> do
        task J, id: "report_invalid_result"
        # task K, id: "log_invalid_result", Output(:success) => color
        task K, id: "log_invalid_result", Output(:success) => End("End.invalid_result", :invalid_result)
      end

      task L, id: :notify_clerk#, Output(Right, :success) => :success
    end

  circuit_hash = Trailblazer::Activity::Magnetic::Generate.( tripletts )

    # puts Cct(circuit_hash)
    Cct(circuit_hash).must_equal %{
#<Start:default>
 {Trailblazer::Circuit::Right} => ActivityBuildTest::A
ActivityBuildTest::A
 {Trailblazer::Circuit::Right} => ActivityBuildTest::B
 {Trailblazer::Circuit::Left} => ActivityBuildTest::B
ActivityBuildTest::B
 {Trailblazer::Circuit::Left} => ActivityBuildTest::A
 {Trailblazer::Circuit::Right} => ActivityBuildTest::G
ActivityBuildTest::G
 {Trailblazer::Circuit::Right} => ActivityBuildTest::I
ActivityBuildTest::I
 {Trailblazer::Circuit::Left} => ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::L
ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Circuit::Right} => #<End:End.invalid_result>
#<End:track_0.>

#<End:End.invalid_result>

ActivityBuildTest::L
 {Trailblazer::Circuit::Right} => #<End:success>
#<End:success>
}

    activity.outputs.must_equal()
  end

  it "::build" do
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => nil,
      Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

    activity = Activity.build do
      task A, id: "inquiry_create", Output(Left, :failure) => "suspend_for_correct"
        task B, id: "suspend_for_correct", Output(:failure) => "inquiry_create", plus_poles: binary_plus_poles

      task G, id: :receive_process_id
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Left, :failure) => -> do
        task J, id: "report_invalid_result"
        # task K, id: "log_invalid_result", Output(:success) => color
        task K, id: "log_invalid_result", Output(:success) => End("End.invalid_result", :invalid_result)
      end

      task L, id: :notify_clerk#, Output(Right, :success) => :success
    end

    Cct(activity.circuit.to_fields.first).must_equal %{
#<Start:default>
 {Trailblazer::Circuit::Right} => ActivityBuildTest::A
ActivityBuildTest::A
 {Trailblazer::Circuit::Right} => ActivityBuildTest::B
 {Trailblazer::Circuit::Left} => ActivityBuildTest::B
ActivityBuildTest::B
 {Trailblazer::Circuit::Left} => ActivityBuildTest::A
 {Trailblazer::Circuit::Right} => ActivityBuildTest::G
ActivityBuildTest::G
 {Trailblazer::Circuit::Right} => ActivityBuildTest::I
ActivityBuildTest::I
 {Trailblazer::Circuit::Left} => ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::L
ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Circuit::Right} => #<End:End.invalid_result>
#<End:track_0.>

#<End:End.invalid_result>

ActivityBuildTest::L
 {Trailblazer::Circuit::Right} => #<End:success>
#<End:success>
}

    activity.outputs.must_equal({ 1 => 2})
  end


  it "what" do
    initial_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      Activity::Magnetic.Output("Signal A", :exception)  => :exception,
      Activity::Magnetic.Output(Circuit::Left, :failure) => :failure )

    seq = Activity::Magnetic::DSL::ProcessElement.(
      Activity::Magnetic::DSL::Alterations.new,
      G,
        id: :receive_process_id,
        strategy: [
          Activity::Magnetic::DSL::FastTrack.method(:step),
          plus_poles: initial_plus_poles,
        ],

        # existing success to new end
        Activity::Magnetic.Output(Right, :success) => Circuit::End.new("End.invalid_result"),

        Activity::Magnetic.Output("Signal A", :exception) => Circuit::End.new("End.signal_a_reached"),
     )

    Seq(seq.to_a).must_equal %{
[:success] ==> ActivityBuildTest::G
 (success)/Right ==> "receive_process_id-Trailblazer::Circuit::Right"
 (exception)/Signal A ==> "receive_process_id-Signal A"
 (failure)/Left ==> :failure
["receive_process_id-Trailblazer::Circuit::Right"] ==> #<End:End.invalid_result>
 []
["receive_process_id-Signal A"] ==> #<End:End.signal_a_reached>
 []
}
  end


  let(:initial_plus_poles) do
    Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      # Activity::Magnetic.Output("Signal A", :exception)  => :exception,
      Activity::Magnetic.Output(Circuit::Left, :failure) => :failure
    )
  end

  it "builder API, what we use in Operation" do
    # this is what happens in Operation.
    incremental = Activity::Magnetic::FastTrack::Builder.new( track_color: :pink, failure_color: :black )
    incremental.step G, id: :G, plus_poles: initial_plus_poles, fail_fast: true # these options we WANT built by Operation (task, id, plus_poles)
    incremental.step I, id: :I, plus_poles: initial_plus_poles
    incremental.fail J, id: :J, plus_poles: initial_plus_poles
    incremental.pass K, id: :K, plus_poles: initial_plus_poles

    sequence = incremental.draft
    pp sequence

    Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :pink
[:pink] ==> ActivityBuildTest::G
 (success)/Right ==> :pink
 (failure)/Left ==> :fail_fast
[:pink] ==> ActivityBuildTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> :black
[:black] ==> ActivityBuildTest::J
 (success)/Right ==> :black
 (failure)/Left ==> :black
[:pink] ==> ActivityBuildTest::K
 (success)/Right ==> :pink
 (failure)/Left ==> :pink
[:pink] ==> #<End:pink>
 []
[:black] ==> #<End:failure>
 []
[:fail_fast] ==> #<End:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast>
 []
}

    activity = incremental.finalize

    # pp activity
  end

  # hand additional DSL options
  it do
    # this is what happens in Operation.
    incremental = Activity::Magnetic::FastTrack::Builder.new( track_color: :pink, failure_color: :black )
    incremental.step G, id: :G, plus_poles: initial_plus_poles, fail_fast: true, Activity::Magnetic.Output("Exception", :exception) => Circuit::End(:exception)
    incremental.step I, id: :I, plus_poles: initial_plus_poles
    incremental.fail J, id: :J, plus_poles: initial_plus_poles
    incremental.pass K, id: :K, plus_poles: initial_plus_poles

    sequence = incremental.draft
    # pp sequence
# puts Seq(sequence)
    Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :pink
[:pink] ==> ActivityBuildTest::G
 (success)/Right ==> :pink
 (failure)/Left ==> :fail_fast
 (exception)/Exception ==> "G-Exception"
[:pink] ==> ActivityBuildTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> :black
[:black] ==> ActivityBuildTest::J
 (success)/Right ==> :black
 (failure)/Left ==> :black
[:pink] ==> ActivityBuildTest::K
 (success)/Right ==> :pink
 (failure)/Left ==> :pink
[:pink] ==> #<End:pink>
 []
[:black] ==> #<End:failure>
 []
[:fail_fast] ==> #<End:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast>
 []
["G-Exception"] ==> #<End:exception>
 []
}
  end

  describe "Path::Builder" do
    let(:initial_plus_poles) do
      Activity::Magnetic::DSL::PlusPoles.new.merge(
        Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      )
    end

    # with all options.
    it do
      incremental = Activity::Magnetic::Path::Builder.new( track_color: :pink )
      incremental.task G, id: G, plus_poles: initial_plus_poles, Activity::Magnetic.Output("Exception", :exception) => Circuit::End(:exception)
      incremental.task I, id: I, plus_poles: initial_plus_poles, Activity::Magnetic.Output(Circuit::Left, :failure) => Circuit::End(:failure)

      sequence = incremental.draft

      Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :pink
[:pink] ==> ActivityBuildTest::G
 (success)/Right ==> :pink
 (exception)/Exception ==> "ActivityBuildTest::G-Exception"
[:pink] ==> ActivityBuildTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> "ActivityBuildTest::I-Trailblazer::Circuit::Left"
[:pink] ==> #<End:pink>
 []
["ActivityBuildTest::G-Exception"] ==> #<End:exception>
 []
["ActivityBuildTest::I-Trailblazer::Circuit::Left"] ==> #<End:failure>
 []
}
    end

    # with plus_poles.
    it do
      incremental = Activity::Magnetic::Path::Builder.new( plus_poles: initial_plus_poles )
      incremental.task G, id: G, Activity::Magnetic.Output("Exception", :exception) => Circuit::End(:exception)
      incremental.task I, id: I, Activity::Magnetic.Output(Circuit::Left, :failure) => Circuit::End(:failure)

      sequence = incremental.draft

      Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :success
[:success] ==> ActivityBuildTest::G
 (success)/Right ==> :success
 (exception)/Exception ==> "ActivityBuildTest::G-Exception"
[:success] ==> ActivityBuildTest::I
 (success)/Right ==> :success
 (failure)/Left ==> "ActivityBuildTest::I-Trailblazer::Circuit::Left"
[:success] ==> #<End:success>
 []
["ActivityBuildTest::G-Exception"] ==> #<End:exception>
 []
["ActivityBuildTest::I-Trailblazer::Circuit::Left"] ==> #<End:failure>
 []
}
    end
  end
end


