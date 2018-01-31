require "test_helper"

# Low-level API tests for Builder::Path.
class DSLPathTest < Minitest::Spec
  Builder = Trailblazer::Activity::Magnetic::Builder

  class G; end
  class I; end

  describe "Procedural interface" do
    let(:initial_plus_poles) do
      Activity::Magnetic::PlusPoles.new.merge(
        Activity.Output(Activity::Right, :success) => :success,
      )
    end

    # with all options.
    it do
      normalizer, _ = Activity::Magnetic::Normalizer.build(outputs: Builder::Path.DefaultOutputs)

      builder, adds = Builder::Path.for( normalizer, {track_color: :pink} )

      _adds, _ = builder.insert( :task, {task: G}, id: G, plus_poles: initial_plus_poles, Activity.Output("Exception", :exception) => Activity.End(:exception) )
      adds += _adds
      _adds, _ = builder.insert( :task, {task: I}, id: I, plus_poles: initial_plus_poles, Activity.Output(Activity::Left, :failure) => Activity.End(:failure) )
      adds += _adds

      sequence = Activity::Magnetic::Builder::Finalizer.adds_to_tripletts(adds)

      Seq(sequence).must_equal %{
[] ==> #<Start/:default>
 (success)/Right ==> :pink
[:pink] ==> DSLPathTest::G
 (success)/Right ==> :pink
 (exception)/Exception ==> "DSLPathTest::G-Exception"
[:pink] ==> DSLPathTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> "DSLPathTest::I-Trailblazer::Activity::Left"
[:pink] ==> #<End/:success>
 []
["DSLPathTest::G-Exception"] ==> #<End/:exception>
 []
["DSLPathTest::I-Trailblazer::Activity::Left"] ==> #<End/:failure>
 []
}
    end

    # with plus_poles.
    it do
      normalizer, _ = Activity::Magnetic::Normalizer.build(outputs: Builder::Path.DefaultOutputs)

      builder, adds = Builder::Path.for( normalizer, {plus_poles: initial_plus_poles} )

      _adds, _ = builder.insert( :task, {task: G}, id: G, Activity.Output("Exception", :exception) => Activity.End(:exception) )
      adds += _adds
      _adds, _ = builder.insert( :task, {task: I}, id: I, Activity.Output(Activity::Left, :failure) => Activity.End(:failure) )
      adds += _adds

      sequence = Activity::Magnetic::Builder::Finalizer.adds_to_tripletts(adds)

      Seq(sequence).must_equal %{
[] ==> #<Start/:default>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::G
 (success)/Right ==> :success
 (failure)/Left ==> nil
 (exception)/Exception ==> "DSLPathTest::G-Exception"
[:success] ==> DSLPathTest::I
 (success)/Right ==> :success
 (failure)/Left ==> "DSLPathTest::I-Trailblazer::Activity::Left"
[:success] ==> #<End/:success>
 []
["DSLPathTest::G-Exception"] ==> #<End/:exception>
 []
["DSLPathTest::I-Trailblazer::Activity::Left"] ==> #<End/:failure>
 []
}
    end
  end
end
