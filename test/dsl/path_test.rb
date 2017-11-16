require "test_helper"

class DSLPathTest < Minitest::Spec
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

  Builder = Activity::Magnetic::Path::Builder

  it "standard path ends in End.success/:success" do
    seq = Builder.plan do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::J
 (success)/Right ==> :success
[:success] ==> DSLPathTest::K
 (success)/Right ==> :success
[:success] ==> #<End:success/:success>
 []
}
  end

  it "Output(:success) finds the correct Output" do
    seq = Builder.plan( track_color: :"track_9" ) do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result", Output(:success) => End("End.invalid_result", :invalid_result)
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::J
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::K
 (success)/Right ==> "log_invalid_result-Trailblazer::Circuit::Right"
[:track_9] ==> #<End:track_9/:success>
 []
["log_invalid_result-Trailblazer::Circuit::Right"] ==> #<End:End.invalid_result/:invalid_result>
 []
}
  end

  # Activity.plan( track_color: :pink )
  it "Output(Right, :success) => End adds new End.invalid_result" do
    seq = Builder.plan( track_color: :"track_9" ) do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result", Output(Right, :success) => End("End.invalid_result", :invalid_result)
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::J
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::K
 (success)/Right ==> "log_invalid_result-Trailblazer::Circuit::Right"
[:track_9] ==> #<End:track_9/:success>
 []
["log_invalid_result-Trailblazer::Circuit::Right"] ==> #<End:End.invalid_result/:invalid_result>
 []
}
  end


  #---
  #- nested blocks
  it "nested PATH ends in End.invalid" do
    # binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
    #   Activity::Magnetic.Output(Circuit::Right, :success) => nil,
    #   Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

    activity = Activity.build do
      task A, id: "A"
      task B, id: "B", Output(Left, :failure) => Path(end_semantic: :invalid) do
        task C, id: "C"
        task K, id: "K"#, Output(:success) => End("End.invalid_result", :invalid_result)
      end
      task D, id: "D"
    end

# puts Cct(activity.circuit.to_fields.first)

    Cct(activity.circuit.to_fields.first).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => DSLPathTest::A
DSLPathTest::A
 {Trailblazer::Circuit::Right} => DSLPathTest::B
DSLPathTest::B
 {Trailblazer::Circuit::Left} => DSLPathTest::C
 {Trailblazer::Circuit::Right} => DSLPathTest::D
DSLPathTest::C
 {Trailblazer::Circuit::Right} => DSLPathTest::K
DSLPathTest::K
 {Trailblazer::Circuit::Right} => #<End:track_0./:invalid>
#<End:track_0./:invalid>

DSLPathTest::D
 {Trailblazer::Circuit::Right} => #<End:success/:success>
#<End:success/:success>
}

    activity.outputs.values.must_equal [:invalid, :success]
  end


  describe "Procedural interface" do
    let(:initial_plus_poles) do
      Activity::Magnetic::DSL::PlusPoles.new.merge(
        Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      )
    end

    # with all options.
    it do
      incremental = Activity::Magnetic::Path::Builder.new( track_color: :pink )
      incremental.task G, id: G, plus_poles: initial_plus_poles, Activity::Magnetic.Output("Exception", :exception) => Activity::Magnetic.End(:exception)
      incremental.task I, id: I, plus_poles: initial_plus_poles, Activity::Magnetic.Output(Circuit::Left, :failure) => Activity::Magnetic.End(:failure)

      sequence = incremental.draft

      Seq(sequence).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :pink
[:pink] ==> DSLPathTest::G
 (success)/Right ==> :pink
 (exception)/Exception ==> "DSLPathTest::G-Exception"
[:pink] ==> DSLPathTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> "DSLPathTest::I-Trailblazer::Circuit::Left"
[:pink] ==> #<End:pink/:success>
 []
["DSLPathTest::G-Exception"] ==> #<End:exception/:exception>
 []
["DSLPathTest::I-Trailblazer::Circuit::Left"] ==> #<End:failure/:failure>
 []
}
    end

    # with plus_poles.
    it do
      incremental = Activity::Magnetic::Path::Builder.new( plus_poles: initial_plus_poles )
      incremental.task G, id: G, Activity::Magnetic.Output("Exception", :exception) => Activity::Magnetic.End(:exception)
      incremental.task I, id: I, Activity::Magnetic.Output(Circuit::Left, :failure) => Activity::Magnetic.End(:failure)

      sequence = incremental.draft

      Seq(sequence).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::G
 (success)/Right ==> :success
 (exception)/Exception ==> "DSLPathTest::G-Exception"
[:success] ==> DSLPathTest::I
 (success)/Right ==> :success
 (failure)/Left ==> "DSLPathTest::I-Trailblazer::Circuit::Left"
[:success] ==> #<End:success/:success>
 []
["DSLPathTest::G-Exception"] ==> #<End:exception/:exception>
 []
["DSLPathTest::I-Trailblazer::Circuit::Left"] ==> #<End:failure/:failure>
 []
}
    end
  end
end
