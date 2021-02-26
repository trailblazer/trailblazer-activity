require "test_helper"

class TaskBuilderTest < Minitest::Spec
  describe "#inspect" do
    it { expect(Activity::TaskBuilder::Binary(:imaproc).inspect).must_equal %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=imaproc>} }
  end
end
