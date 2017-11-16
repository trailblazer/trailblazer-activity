require "test_helper"

class DSLFastTrackTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right

  class A; end
  class B; end
  class C; end
  class D; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  Builder = Activity::Magnetic::FastTrack::Builder

  let(:initial_plus_poles) do
    Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      # Activity::Magnetic.Output("Signal A", :exception)  => :exception,
      Activity::Magnetic.Output(Circuit::Left, :failure) => :failure
    )
  end

  it "builder API, what we use in Operation" do
    # this is what happens in Operation.
    incremental = Builder.new( track_color: :pink, failure_color: :black )
    incremental.step G, id: :G, plus_poles: initial_plus_poles, fail_fast: true # these options we WANT built by Operation (task, id, plus_poles)
    incremental.step I, id: :I, plus_poles: initial_plus_poles
    incremental.fail J, id: :J, plus_poles: initial_plus_poles
    incremental.pass K, id: :K, plus_poles: initial_plus_poles

    sequence = incremental.draft
    pp sequence

    Seq(sequence).must_equal %{
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
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
}

    activity = incremental.finalize

    # pp activity
  end

  # hand additional DSL options
  it do
    # this is what happens in Operation.
    incremental = Builder.new( track_color: :pink, failure_color: :black )
    incremental.step G, id: :G, plus_poles: initial_plus_poles, fail_fast: true, Activity::Magnetic.Output("Exception", :exception) => Activity::Magnetic.End(:exception)
    incremental.step I, id: :I, plus_poles: initial_plus_poles
    incremental.fail J, id: :J, plus_poles: initial_plus_poles
    incremental.pass K, id: :K, plus_poles: initial_plus_poles

    sequence = incremental.draft
    # pp sequence
# puts Seq(sequence)
    Seq(sequence).must_equal %{
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
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
["G-Exception"] ==> #<End:exception/:exception>
 []
}
  end
end
