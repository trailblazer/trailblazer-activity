require "test_helper"

class TaskBuilderTest < Minitest::Spec
  describe "#inspect" do
    it { Activity::TaskBuilder::Binary( "{i am a proc}" ).inspect.must_equal %{#<Trailblazer::Activity::TaskBuilder::Task user_proc={i am a proc}>} }
  end
end
