require "test_helper"

class DSLFastTrackTest < Minitest::Spec
  Left = Trailblazer::Activity::Left
  Right = Trailblazer::Activity::Right

  class A; end
  class B; end
  class C; end
  class D; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  Builder   = Activity::Magnetic::Builder::FastTrack
  PlusPoles = Activity::Magnetic::DSL::PlusPoles

  let(:initial_plus_poles) do
    Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => :success,
      # Activity.Output("Signal A", :exception)  => :exception,
      Activity.Output(Activity::Left, :failure) => :failure
    )
  end

  def assert_main(sequence, expected)
    Seq(sequence).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success#{expected}[:success] ==> #<End:success/:success>
 []
[:failure] ==> #<End:failure/:failure>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
}
  end

  it "builder API, what we use in Operation" do
    initial_plus_poles = self.initial_plus_poles

    # this is what happens in Operation.
    seq, adds = Builder.draft( track_color: :pink, failure_color: :black ) do
      step G, id: :G, plus_poles: initial_plus_poles, fail_fast: true # these options we WANT built by Operation (task, id, plus_poles)
      step I, id: :I, plus_poles: initial_plus_poles
      fail J, id: :J, plus_poles: initial_plus_poles
      pass K, id: :K, plus_poles: initial_plus_poles
    end

    # pp seq

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :pink
[:pink] ==> DSLFastTrackTest::G
 (success)/Right ==> :pink
 (failure)/Left ==> :fail_fast
[:pink] ==> DSLFastTrackTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> :black
[:black] ==> DSLFastTrackTest::J
 (success)/Right ==> :black
 (failure)/Left ==> :black
[:pink] ==> DSLFastTrackTest::K
 (success)/Right ==> :pink
 (failure)/Left ==> :pink
[:pink] ==> #<End:pink/:success>
 []
[:black] ==> #<End:black/:failure>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
}

    activity = Builder.finalize(adds)

    # pp activity
  end

  #---
  #- test options

  it "adds :pass_fast pole" do
    seq, adds = Builder.draft do
      step G, pass_fast: true
    end

    assert_main seq, %{
[:success] ==> DSLFastTrackTest::G
 (success)/Right ==> :pass_fast
 (failure)/Left ==> :failure
}
  end

  it "does NOT add another :pass_fast pole when :plus_poles are given" do
    plus_poles = plus_poles_for( Signal => :success, "Another" => :failure )

    seq, adds = Builder.draft do
      step G, plus_poles: plus_poles, pass_fast: true
    end

    assert_main seq, %{
[:success] ==> DSLFastTrackTest::G
 (success)/Signal ==> :pass_fast
 (failure)/Another ==> :failure
}
  end
  # pass_fast: true simply means: color my :success Output with :pass_fast color
  it "does NOT override :pass_fast pole when :poles_poles are given, >>>>>>>>>>>>>>>>>>>>>" do
    plus_poles = plus_poles_for( Signal => :success, "Another" => :failure, "Pff" => :pass_fast )

    seq, adds = Builder.draft do
      step G, plus_poles: plus_poles, pass_fast: true, id: :G
    end

    # only overwrites success's color to :pass_fast
    assert_main seq, %{
[:success] ==> DSLFastTrackTest::G
 (success)/Signal ==> :pass_fast
 (failure)/Another ==> :failure
 (pass_fast)/Pff ==> :pass_fast
}

    process, _ = Builder::Finalizer.(adds)

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => DSLFastTrackTest::G
DSLFastTrackTest::G
 {Another} => #<End:failure/:failure>
 {Signal} => #<End:pass_fast/:pass_fast>
 {Pff} => #<End:pass_fast/:pass_fast>
#<End:success/:success>

#<End:failure/:failure>

#<End:pass_fast/:pass_fast>

#<End:fail_fast/:fail_fast>
}
  end

  it "adds :fail_fast pole" do
    seq, adds = Builder.draft do
      step G, fail_fast: true
    end

    assert_main seq, %{
[:success] ==> DSLFastTrackTest::G
 (success)/Right ==> :success
 (failure)/Left ==> :fail_fast
}
  end

  #- :fast_track
  it "adds :fail_fast and :pass_fast pole" do
    seq, adds = Builder.draft do
      step G, fast_track: true
    end

    assert_main seq, %{
[:success] ==> DSLFastTrackTest::G
 (success)/Right ==> :success
 (failure)/Left ==> :failure
 (fail_fast)/Magnetic::Builder::FastTrack::FailFast ==> :fail_fast
 (pass_fast)/Magnetic::Builder::FastTrack::PassFast ==> :pass_fast
}
  end

  #- :fast_track
  it "don't overwrite :pass_fast/:fail_fast colored outputs that are existing in :plus_poles" do
    plus_poles = plus_poles_for(
      Signal    => :success,
      "Another" => :failure,
      "Pff"     => :pass_fast, # we already provide :pass_fast
    )

    seq, adds = Builder.draft do
      step G, fast_track: true, plus_poles: plus_poles
    end

    assert_main seq, %{
[:success] ==> DSLFastTrackTest::G
 (success)/Signal ==> :success
 (failure)/Another ==> :failure
 (pass_fast)/Pff ==> :pass_fast
 (fail_fast)/Magnetic::Builder::FastTrack::FailFast ==> :fail_fast
}
  end

  it "additional DSL options override given :plus_poles" do
    # these are PlusPoles as found when nesting another operation.
    plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => :success,
      Activity.Output(Activity::Left,  :failure) => :failure,
      Activity.Output(Activity::Magnetic::Builder::FastTrack::PassFast,  :pass_fast) => :pass_fast,
      Activity.Output(Activity::Magnetic::Builder::FastTrack::FailFast,  :fail_fast) => :fail_fast,
    )

    seq, adds = Builder.draft do
      step G, plus_poles: plus_poles, Output(:success)=> :failure, Output(:pass_fast) => :success
    end

    assert_main seq, %{
[:success] ==> DSLFastTrackTest::G
 (success)/Right ==> :failure
 (failure)/Left ==> :failure
 (pass_fast)/Magnetic::Builder::FastTrack::PassFast ==> :success
 (fail_fast)/Magnetic::Builder::FastTrack::FailFast ==> :fail_fast
}
  end

  describe ":magnetic_to" do
    it "overrides default @track_color" do
      seq, adds = Builder.draft do
        step G, magnetic_to: []
        pass I, magnetic_to: [:pass_me_a_beer]
        fail J, magnetic_to: []
      end

      assert_main seq, %{
[] ==> DSLFastTrackTest::G
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:pass_me_a_beer] ==> DSLFastTrackTest::I
 (success)/Right ==> :success
 (failure)/Left ==> :success
[] ==> DSLFastTrackTest::J
 (success)/Right ==> :failure
 (failure)/Left ==> :failure
}
    end

    it "merges with new connections" do
      seq, adds = Builder.draft do
        step G, magnetic_to: [], id: "G"
        step I, Output(:success) => "G"
      end

      assert_main seq, %{
["Trailblazer::Activity::Right-G"] ==> DSLFastTrackTest::G
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> DSLFastTrackTest::I
 (success)/Right ==> "Trailblazer::Activity::Right-G"
 (failure)/Left ==> :failure
}
    end
  end

  # hand additional DSL options
  it do
    # this is what happens in Operation.
    seq, adds = Builder.draft( track_color: :pink, failure_color: :black ) do
      step G, id: :G, fail_fast: true, Activity.Output("Exception", :exception) => Activity.End(:exception)
      step I, id: :I
      fail J, id: :J
      pass K, id: :K
    end

    # pp sequence
# puts Seq(sequence)
    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :pink
[:pink] ==> DSLFastTrackTest::G
 (success)/Right ==> :pink
 (failure)/Left ==> :fail_fast
 (exception)/Exception ==> "G-Exception"
[:pink] ==> DSLFastTrackTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> :black
[:black] ==> DSLFastTrackTest::J
 (success)/Right ==> :black
 (failure)/Left ==> :black
[:pink] ==> DSLFastTrackTest::K
 (success)/Right ==> :pink
 (failure)/Left ==> :pink
[:pink] ==> #<End:pink/:success>
 []
[:black] ==> #<End:black/:failure>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
["G-Exception"] ==> #<End:exception/:exception>
 []
}
  end

  it "allows to define custom End instance" do
    class MyFail; end
    class MySuccess; end
    class MyPassFast; end
    class MyFailFast; end

    seq, _ = Builder.build track_end: MySuccess, failure_end: MyFail, pass_fast_end: MyPassFast, fail_fast_end: MyFailFast do
      step :a, {}
    end

    Cct( seq ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => :a
:a
 {Trailblazer::Activity::Right} => DSLFastTrackTest::MySuccess
 {Trailblazer::Activity::Left} => DSLFastTrackTest::MyFail
DSLFastTrackTest::MySuccess

DSLFastTrackTest::MyFail

DSLFastTrackTest::MyPassFast

DSLFastTrackTest::MyFailFast
}
  end

  it "allows to provide :plus_poles and customize their connections" do
    initial_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => :success,
      Activity.Output("Signal A", :exception)  => :exception,
      Activity.Output(Activity::Left, :failure) => :failure
    )


    seq, _ = Builder.draft do
      step G,
        id: :receive_process_id,
        plus_poles: initial_plus_poles,

        # existing success to new end
        Activity.Output(Right, :success)        => Activity.End(:invalid_result),
        Activity.Output("Signal A", :exception) => Activity.End(:signal_a_reached)
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLFastTrackTest::G
 (success)/Right ==> "receive_process_id-Trailblazer::Activity::Right"
 (exception)/Signal A ==> "receive_process_id-Signal A"
 (failure)/Left ==> :failure
[:success] ==> #<End:success/:success>
 []
[:failure] ==> #<End:failure/:failure>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
["receive_process_id-Trailblazer::Activity::Right"] ==> #<End:invalid_result/:invalid_result>
 []
["receive_process_id-Signal A"] ==> #<End:signal_a_reached/:signal_a_reached>
 []
}
  end

  it "accepts :before and :group" do
    seq, adds = Builder.draft do
      step J, id: "report_invalid_result"
      step K, id: "log_invalid_result", before: "report_invalid_result"
      step I, id: "start/I", group: :start
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLFastTrackTest::I
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> DSLFastTrackTest::K
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> DSLFastTrackTest::J
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> #<End:success/:success>
 []
[:failure] ==> #<End:failure/:failure>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
}
  end
end
