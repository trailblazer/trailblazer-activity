require "test_helper"

# Low-level API tests for Builder::Path.
class DSLPathTest < Minitest::Spec
  Builder = Trailblazer::Activity::Magnetic::Builder

  class G; end
  class I; end

  describe "Procedural interface" do
    let(:initial_outputs) { { :success => Activity.Output(Activity::Right, :success) } }

    # with all options.
    it do
      normalizer, _ = Activity::Magnetic::Normalizer.build(default_outputs: { :success => Builder::Path.default_outputs[:success] } )

      builder, adds = Builder::Path.for( normalizer, {track_color: :pink} )

      _adds, _ = builder.insert( Builder::Path, :TaskPolarizations, {task: G}, id: G, outputs: initial_outputs, Activity.Output("Exception", :exception) => Activity.End(:exception) )
      adds += _adds
      _adds, _ = builder.insert( Builder::Path, :TaskPolarizations, {task: I}, id: I, outputs: initial_outputs, Activity.Output(Activity::Left, :failure) => Activity.End(:failure) )
      adds += _adds

      SEQ(adds).must_equal %{
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
      normalizer, _ = Activity::Magnetic::Normalizer.build(outputs: Builder::Path.default_outputs)

      builder, adds = Builder::Path.for( normalizer, {outputs: initial_outputs} )

      _adds, _ = builder.insert( Builder::Path, :TaskPolarizations, {task: G}, id: G, Activity.Output("Exception", :exception) => Activity.End(:exception) )
      adds += _adds
      _adds, _ = builder.insert( Builder::Path, :TaskPolarizations, {task: I}, id: I, Activity.Output(Activity::Left, :failure) => Activity.End(:failure) )
      adds += _adds

      SEQ(adds).must_equal %{
[] ==> #<Start/:default>
 (success)/Right ==> :success
[:success] ==> DSLPathTest::G
 (success)/Right ==> :success
 (failure)/Left ==> :failure
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
