require "test_helper"

class Trailblazer::Activity::Magnetic::Builder::Path
        # TODO: remove, only for testing.
      # @return Tripletts
      def self.draft(*args, &block)
        adds = plan( *args, &block )

        return Finalizer.adds_to_tripletts(adds), adds
      end
end

class DSLPathTest < Minitest::Spec
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

  Builder   = Activity::Magnetic::Builder
  Finalizer = Activity::Magnetic::Builder::Finalizer

  it "standard path ends in End.success/:success" do
    adds = Builder::Path.plan do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result"
    end

    seq = Finalizer.adds_to_tripletts(adds)

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

    process, _ = Finalizer.( adds )
    Ends(process).must_equal %{[#<End:success/:success>]}
  end

  it "accepts :before and :group" do
    seq, adds = Builder::Path.draft do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result", before: "report_invalid_result"
      task I, id: "start/I", group: :start
  end

  Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::I
 (success)/Right ==> :success
[:success] ==> DSLPathTest::K
 (success)/Right ==> :success
[:success] ==> DSLPathTest::J
 (success)/Right ==> :success
[:success] ==> #<End:success/:success>
 []
}
  end

  it "allows to define custom End instance" do
    class MyEnd; end

    seq, _ = Builder::Path.build track_end: MyEnd do
      task :a, {}
  end

    Cct( seq ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => :a
:a
 {Trailblazer::Activity::Right} => DSLPathTest::MyEnd
DSLPathTest::MyEnd
}
end

describe ":normalizer" do
  let(:plus_poles) do
    Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => :success,
    )
  end

  it "allows injecting a normalizer" do
    normalizer  = ->(task, options, *args) { [task.inspect, options, *args] }
    _plus_poles = plus_poles

    adds = Builder::Path.plan do
      task I, normalizer: normalizer, plus_poles: _plus_poles
      task K
    end

    seq = Finalizer.adds_to_tripletts(adds)

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> "DSLPathTest::I"
 (success)/Right ==> :success
[:success] ==> DSLPathTest::K
 (success)/Right ==> :success
[:success] ==> #<End:success/:success>
 []
}
  end
end

describe "with :plus_poles" do
  let(:plus_poles) do
    Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => :success,
      Activity.Output(Activity::Left,  :failure) => :failure,
    )
  end

  it "allows overriding existing outputs via semantic=>:new_color" do
    _plus_poles = plus_poles

    seq, adds = Builder::Path.draft do
      task D, plus_poles: _plus_poles, Output(:failure) => :something_completely_different
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::D
 (success)/Right ==> :success
 (failure)/Left ==> :something_completely_different
[:success] ==> #<End:success/:success>
 []
}
  end
end



describe "magnetic_to:" do
  it "allows to skip minus poles" do
    seq, adds = Builder::Path.draft do
      task D, id: "D", magnetic_to: []
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[] ==> DSLPathTest::D
 (success)/Right ==> :success
[:success] ==> #<End:success/:success>
 []
}

    Cct( Finalizer.(adds).first ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<End:success/:success>
DSLPathTest::D
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}
  end

end

  it "fake Railway with Output(Left)s" do
    seq, adds = Builder::Path.draft(track_color: :"track_9") do
      task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)
      task K, id: "validate", Output(Left, :failure) => End("End.invalid", :invalid)
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> "extract-Trailblazer::Activity::Left"
[:track_9] ==> DSLPathTest::K
 (success)/Right ==> :track_9
 (failure)/Left ==> "validate-Trailblazer::Activity::Left"
[:track_9] ==> #<End:track_9/:success>
 []
["extract-Trailblazer::Activity::Left"] ==> #<End:End.extract.key_not_found/:key_not_found>
 []
["validate-Trailblazer::Activity::Left"] ==> #<End:End.invalid/:invalid>
 []
}

    process, _ = Finalizer.( adds )
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

    process, _ = Finalizer.( adds )

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => DSLPathTest::J
DSLPathTest::J
 {Trailblazer::Activity::Right} => DSLPathTest::K
 {Trailblazer::Activity::Left} => #<End:End.extract.key_not_found/:key_not_found>
DSLPathTest::K
 {Trailblazer::Activity::Left} => DSLPathTest::A
 {Trailblazer::Activity::Right} => DSLPathTest::L
DSLPathTest::A
 {Trailblazer::Activity::Right} => DSLPathTest::B
DSLPathTest::B
 {Trailblazer::Activity::Right} => DSLPathTest::J
DSLPathTest::L
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>

#<End:End.extract.key_not_found/:key_not_found>

#<End:track_0./:success>
}
    Ends(process).must_equal %{[#<End:success/:success>,#<End:End.extract.key_not_found/:key_not_found>]}
  end

  it "Output(:success) finds the correct Output" do
    seq, adds = Builder::Path.draft( track_color: :"track_9" ) do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result", Output(:success) => End("End.invalid_result", :invalid_result)
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::J
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::K
 (success)/Right ==> "log_invalid_result-Trailblazer::Activity::Right"
[:track_9] ==> #<End:track_9/:success>
 []
["log_invalid_result-Trailblazer::Activity::Right"] ==> #<End:End.invalid_result/:invalid_result>
 []
}
  end

  # Activity.plan( track_color: :pink )
  it "Output(Right, :success) => End adds new End.invalid_result" do
    seq, adds = Builder::Path.draft( track_color: :"track_9" ) do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result", Output(Right, :success) => End("End.invalid_result", :invalid_result)
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::J
 (success)/Right ==> :track_9
[:track_9] ==> DSLPathTest::K
 (success)/Right ==> "log_invalid_result-Trailblazer::Activity::Right"
[:track_9] ==> #<End:track_9/:success>
 []
["log_invalid_result-Trailblazer::Activity::Right"] ==> #<End:End.invalid_result/:invalid_result>
 []
}
    process, _ = Finalizer.( adds )
    Ends(process).must_equal %{[#<End:End.invalid_result/:invalid_result>]}
  end


  #---
  #- nested blocks
  it "nested PATH ends in End.invalid" do
    # binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
    #   Activity.Output(Activity::Right, :success) => nil,
    #   Activity.Output(Activity::Left, :failure) => nil )

    adds = Builder::Path.plan do
      task A, id: "A"
      task B, id: "B", Output(Left, :failure) => Path(end_semantic: :invalid) do
        task C, id: "C"
        task K, id: "K"#, Output(:success) => End("End.invalid_result", :invalid_result)
      end
      task D, id: "D"
    end

    seq = Finalizer.adds_to_tripletts(adds)

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


    process, _ = Finalizer.( adds )
    Ends(process).must_equal %{[#<End:success/:success>,#<End:track_0./:invalid>]}

    Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => DSLPathTest::A
DSLPathTest::A
 {Trailblazer::Activity::Right} => DSLPathTest::B
DSLPathTest::B
 {Trailblazer::Activity::Left} => DSLPathTest::C
 {Trailblazer::Activity::Right} => DSLPathTest::D
DSLPathTest::C
 {Trailblazer::Activity::Right} => DSLPathTest::K
DSLPathTest::K
 {Trailblazer::Activity::Right} => #<End:track_0./:invalid>
DSLPathTest::D
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>

#<End:track_0./:invalid>
}
  end

  it "with :normalizer" do
    binary_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => nil,
      Activity.Output(Activity::Left, :failure) => nil )

    normalizer = ->(task, local_options, options, seq_options) { [ task, local_options.merge(plus_poles: binary_plus_poles), options, seq_options ] }

    seq, adds = Builder::Path.draft( {}, normalizer ) do
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
 (failure)/Left ==> "-Trailblazer::Activity::Left"
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
["-Trailblazer::Activity::Left"] ==> #<End:left/:left>
 []
}
  end

  describe ":type" do
    it ":type => :end" do
      seq, adds = Builder::Path.draft do
        task A, id: "A"
        task B, id: "B", type: :End #, Output(:failure) => Path(end_semantic: :invalid) do
         # task C, Output(:failure) => End(:left, :left)
         # task K, id: "K"#, Output(:success) => End("End.invalid_result", :invalid_result)
        #end
        task D, id: "D"
      end

      Cct( Finalizer.(adds).first ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => DSLPathTest::A
DSLPathTest::A
 {Trailblazer::Activity::Right} => DSLPathTest::B
DSLPathTest::B

DSLPathTest::D
 {Trailblazer::Activity::Right} => DSLPathTest::D
#<End:success/:success>
}
    end

    it "multiple type: :End with magnetic_to:" do
      seq, adds = Builder::Path.draft do
        task A, id: "A"
        task B, id: "B", type: :End
        task D, id: "D", magnetic_to: [] # start event
        task I, id: "I", type: :End
        task G, id: "G", magnetic_to: [] # start event
      end

      Cct( Finalizer.(adds).first ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => DSLPathTest::A
DSLPathTest::A
 {Trailblazer::Activity::Right} => DSLPathTest::B
DSLPathTest::B

DSLPathTest::D
 {Trailblazer::Activity::Right} => DSLPathTest::I
DSLPathTest::I

DSLPathTest::G
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}
    end
  end


  describe "Procedural interface" do
    let(:initial_plus_poles) do
      Activity::Magnetic::DSL::PlusPoles.new.merge(
        Activity.Output(Activity::Right, :success) => :success,
      )
    end

    # with all options.
    it do
      builder, adds = Builder::Path.for( Builder::DefaultNormalizer.new(plus_poles: Builder::Path.default_plus_poles), {track_color: :pink} )

      _adds, _ = builder.task( G, id: G, plus_poles: initial_plus_poles, Activity.Output("Exception", :exception) => Activity.End(:exception) )
      adds += _adds
      _adds, _ = builder.task( I, id: I, plus_poles: initial_plus_poles, Activity.Output(Activity::Left, :failure) => Activity.End(:failure) )
      adds += _adds

      sequence = Finalizer.adds_to_tripletts(adds)

      Seq(sequence).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :pink
[:pink] ==> DSLPathTest::G
 (success)/Right ==> :pink
 (exception)/Exception ==> "DSLPathTest::G-Exception"
[:pink] ==> DSLPathTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> "DSLPathTest::I-Trailblazer::Activity::Left"
[:pink] ==> #<End:pink/:success>
 []
["DSLPathTest::G-Exception"] ==> #<End:exception/:exception>
 []
["DSLPathTest::I-Trailblazer::Activity::Left"] ==> #<End:failure/:failure>
 []
}

      process, _ = Finalizer.(adds)
      Ends(process).must_equal %{[#<End:pink/:success>,#<End:exception/:exception>,#<End:failure/:failure>]}
    end

    # with plus_poles.
    it do
      builder, adds = Builder::Path.for( Builder::DefaultNormalizer.new(plus_poles: Builder::Path.default_plus_poles), {plus_poles: initial_plus_poles} )

      _adds, _ = builder.task G, id: G, Activity.Output("Exception", :exception) => Activity.End(:exception)
      adds += _adds
      _adds, _ = builder.task I, id: I, Activity.Output(Activity::Left, :failure) => Activity.End(:failure)
      adds += _adds

      sequence = Finalizer.adds_to_tripletts(adds)

      Seq(sequence).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::G
 (success)/Right ==> :success
 (exception)/Exception ==> "DSLPathTest::G-Exception"
[:success] ==> DSLPathTest::I
 (success)/Right ==> :success
 (failure)/Left ==> "DSLPathTest::I-Trailblazer::Activity::Left"
[:success] ==> #<End:success/:success>
 []
["DSLPathTest::G-Exception"] ==> #<End:exception/:exception>
 []
["DSLPathTest::I-Trailblazer::Activity::Left"] ==> #<End:failure/:failure>
 []
}
      process, _ = Finalizer.(adds)
      Ends(process).must_equal %{[#<End:success/:success>,#<End:exception/:exception>,#<End:failure/:failure>]}
    end
  end
end
