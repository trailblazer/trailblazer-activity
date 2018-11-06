require "test_helper"

class IntrospectionTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

  Right = Trailblazer::Activity::Right
  Left  = Trailblazer::Activity::Left

  let(:activity) do
    nested = bc

    activity = Module.new do
      extend Activity::Path()
      task task: A
      task task: nested, Output(nested.outputs.keys.first, :success) => :success
      task task: D, id: "D"
    end
  end

  let(:bc) do
    activity = Module.new do
      extend Activity::Path()
      task task: B
      task task: C
    end
  end

  describe "#collect" do
    it "collects all tasks of a flat activity" do
      all_tasks = Activity::Introspect.collect(bc) do |task, connections|
        task
      end

      all_tasks.size.must_equal 4
      all_tasks[1..2].must_equal [B, C]
    end

    it "iterates over each task element in the top activity" do
      all_tasks = Activity::Introspect.collect(activity) do |task, connections|
        task
      end

      all_tasks.size.must_equal 5
      all_tasks[1..3].must_equal [A, bc, D]
      # TODO: test start and end!
    end

    it "iterates over all task elements recursively" do
      all_tasks = Activity::Introspect.collect(activity, recursive: true) do |task, connections|
        task
      end

      all_tasks.size.must_equal 9
      all_tasks[1..2].must_equal [A, bc]
      all_tasks[4..5].must_equal [B, C]
    end
  end

  describe "Introspect::Graph" do
    let(:activity) do
      Module.new do
        extend Activity::Path()

        task task: "I am not callable!"
        task task: B, id: "B"
      end
    end

    let(:graph) { graph = Activity::Introspect::Graph(activity) }

    describe "#find" do
      let(:node) { graph.find("B") }
      it { node[:id].must_equal "B" }
      it { assert_outputs(node, success: Right, failure: Left) }
      it { node[:task].must_equal B }

      describe "with Start.default" do
        let(:node) { graph.find("Start.default") }
        it { node[:id].must_equal "Start.default" }
        it { assert_outputs(node, success: Right) }
        it { node[:task].must_equal activity.to_h[:circuit].to_h[:start_task] }
      end

      describe "with block" do
        let(:node) { graph.find { |node| node[:task] == B } }

        it { node[:id].must_equal "B" }
        it { node[:task].must_equal B }
        it { assert_outputs(node, success: Right, failure: Left) }
      end
    end

    def assert_outputs(node, map)
      Hash[
        node.outputs.collect { |out| [out.semantic, out.signal] }
      ].must_equal(map)
    end
  end
end
