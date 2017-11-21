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
    seq, adds = Builder.draft do
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

    process, _ = Builder.finalize( adds )
    Ends(process).must_equal %{[#<End:success/:success>]}
  end

  it "fake Railway with Output(Left)s" do
    seq, adds = Builder.draft(track_color: :"track_9") do
      task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)
      task K, id: "validate", Output(Left, :failure) => End("End.invalid", :invalid)
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> "extract-Trailblazer::Circuit::Left"
[:track_9] ==> DSLPathTest::K
 (success)/Right ==> :track_9
 (failure)/Left ==> "validate-Trailblazer::Circuit::Left"
[:track_9] ==> #<End:track_9/:success>
 []
["extract-Trailblazer::Circuit::Left"] ==> #<End:End.extract.key_not_found/:key_not_found>
 []
["validate-Trailblazer::Circuit::Left"] ==> #<End:End.invalid/:invalid>
 []
}

    process, _ = Builder.finalize( adds )
    Ends(process).must_equal %{[#<End:track_9/:success>,#<End:End.extract.key_not_found/:key_not_found>,#<End:End.invalid/:invalid>]}
  end

  it "with nesting and circular" do
    seq, adds = Activity::Process.draft do
      task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)
      task K, id: "validate", Output(Left, :failure) => Path() do
        task A, id: "A"
        task B, id: "B", Output(:success) => "extract" # go back to J{extract}.
      end
      task L, id: "L"
    end

    # puts Seq(seq)

    process, _ = Builder.finalize( adds )

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => DSLPathTest::J
DSLPathTest::J
 {Trailblazer::Circuit::Right} => DSLPathTest::K
 {Trailblazer::Circuit::Left} => #<End:End.extract.key_not_found/:key_not_found>
DSLPathTest::K
 {Trailblazer::Circuit::Left} => DSLPathTest::A
 {Trailblazer::Circuit::Right} => DSLPathTest::L
DSLPathTest::A
 {Trailblazer::Circuit::Right} => DSLPathTest::B
DSLPathTest::B
 {Trailblazer::Circuit::Right} => DSLPathTest::J
DSLPathTest::L
 {Trailblazer::Circuit::Right} => #<End:success/:success>
#<End:success/:success>

#<End:End.extract.key_not_found/:key_not_found>

#<End:track_0./:success>
}
    Ends(process).must_equal %{[#<End:success/:success>,#<End:End.extract.key_not_found/:key_not_found>]}
  end

  it "Output(:success) finds the correct Output" do
    seq, adds = Builder.draft( track_color: :"track_9" ) do
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
    seq, adds = Builder.draft( track_color: :"track_9" ) do
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
    process, _ = Builder.finalize( adds )
    Ends(process).must_equal %{[#<End:End.invalid_result/:invalid_result>]}
  end


  #---
  #- nested blocks
  it "nested PATH ends in End.invalid" do
    # binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
    #   Activity::Magnetic.Output(Circuit::Right, :success) => nil,
    #   Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

    seq, adds = Builder.draft do
      task A, id: "A"
      task B, id: "B", Output(Left, :failure) => Path(end_semantic: :invalid) do
        task C, id: "C"
        task K, id: "K"#, Output(:success) => End("End.invalid_result", :invalid_result)
      end
      task D, id: "D"
    end

Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::A
 (success)/Right ==> :success
[:success] ==> DSLPathTest::B
 (success)/Right ==> :success
 (failure)/Left ==> "track_0."
["track_0."] ==> DSLPathTest::C
 (success)/Right ==> "track_0."
["track_0."] ==> DSLPathTest::K
 (success)/Right ==> "track_0."
[:success] ==> DSLPathTest::D
 (success)/Right ==> :success
[:success] ==> #<End:success/:success>
 []
["track_0."] ==> #<End:track_0./:invalid>
 []
}


    process, _ = Builder.finalize( adds )
    Ends(process).must_equal %{[#<End:success/:success>,#<End:track_0./:invalid>]}

    Cct(process).must_equal %{
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
DSLPathTest::D
 {Trailblazer::Circuit::Right} => #<End:success/:success>
#<End:success/:success>

#<End:track_0./:invalid>
}
  end

  it "with :normalizer" do
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => nil,
      Activity::Magnetic.Output(Circuit::Left, :failure) => nil )

    normalizer = ->(task, options) { [ task, options.merge(plus_poles: binary_plus_poles) ] }

    seq, adds = Builder.draft( {}, normalizer ) do
      task A, id: "A"
      task B, id: "B", Output(:failure) => Path(end_semantic: :invalid) do
        task C, Output(:failure) => End(:left, :left)
        task K, id: "K"#, Output(:success) => End("End.invalid_result", :invalid_result)
      end
      task D # no :id.
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::A
 (success)/Right ==> :success
 (failure)/Left ==> nil
[:success] ==> DSLPathTest::B
 (success)/Right ==> :success
 (failure)/Left ==> "track_0."
["track_0."] ==> DSLPathTest::C
 (success)/Right ==> "track_0."
 (failure)/Left ==> "-Trailblazer::Circuit::Left"
["track_0."] ==> DSLPathTest::K
 (success)/Right ==> "track_0."
 (failure)/Left ==> nil
[:success] ==> DSLPathTest::D
 (success)/Right ==> :success
 (failure)/Left ==> nil
[:success] ==> #<End:success/:success>
 []
["track_0."] ==> #<End:track_0./:invalid>
 []
["-Trailblazer::Circuit::Left"] ==> #<End:left/:left>
 []
}
end


  describe "Procedural interface" do
    let(:initial_plus_poles) do
      Activity::Magnetic::DSL::PlusPoles.new.merge(
        Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      )
    end

    # with all options.
    it do
      incremental = Activity::Magnetic::Path::Builder.new( {track_color: :pink}, Activity::Magnetic::Path::Builder::DefaultNormalizer )
      incremental.task G, id: G, plus_poles: initial_plus_poles, Activity::Magnetic.Output("Exception", :exception) => Activity::Magnetic.End(:exception)
      incremental.task I, id: I, plus_poles: initial_plus_poles, Activity::Magnetic.Output(Circuit::Left, :failure) => Activity::Magnetic.End(:failure)

      sequence, adds = incremental.draft

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

      process, _ = Builder.finalize(adds)
      Ends(process).must_equal %{[#<End:pink/:success>,#<End:exception/:exception>,#<End:failure/:failure>]}
    end

    # with plus_poles.
    it do
      incremental = Activity::Magnetic::Path::Builder.new( {plus_poles: initial_plus_poles}, Activity::Magnetic::Path::Builder::DefaultNormalizer )
      incremental.task G, id: G, Activity::Magnetic.Output("Exception", :exception) => Activity::Magnetic.End(:exception)
      incremental.task I, id: I, Activity::Magnetic.Output(Circuit::Left, :failure) => Activity::Magnetic.End(:failure)

      sequence, adds = incremental.draft

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
      process, _ = Builder.finalize(adds)
      Ends(process).must_equal %{[#<End:success/:success>,#<End:exception/:exception>,#<End:failure/:failure>]}
    end
  end
end
