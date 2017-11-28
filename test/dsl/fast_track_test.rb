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

  Builder = Activity::Magnetic::Builder::FastTrack

  let(:initial_plus_poles) do
    Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      # Activity::Magnetic.Output("Signal A", :exception)  => :exception,
      Activity::Magnetic.Output(Circuit::Left, :failure) => :failure
    )
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
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
}

    activity = Builder.finalize(adds)

    # pp activity
  end

  # hand additional DSL options
  it do
    # this is what happens in Operation.
    seq, adds = Builder.draft( track_color: :pink, failure_color: :black ) do
      step G, id: :G, fail_fast: true, Activity::Magnetic.Output("Exception", :exception) => Activity::Magnetic.End(:exception)
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
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
["G-Exception"] ==> #<End:exception/:exception>
 []
}
  end

  it "allows to define custom End instance" do
    class MyFail; end
    class MySuccess; end

    seq, _ = Builder.build track_end: MySuccess, failure_end: MyFail do
      step :a, {}
    end

    Cct( seq ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => :a
:a
 {Trailblazer::Circuit::Right} => DSLFastTrackTest::MySuccess
 {Trailblazer::Circuit::Left} => DSLFastTrackTest::MyFail
DSLFastTrackTest::MySuccess

DSLFastTrackTest::MyFail

#<End:fail_fast/:fail_fast>

#<End:pass_fast/:pass_fast>
}
  end
end
