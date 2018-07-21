require "test_helper"

class IntrospectionTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

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

  # TODO: test Activity::Railway() to make sure that works for Trailblazer::Operation
  describe "Introspect::Graph" do
    let(:activity) do
      nested = bc

      Module.new do
        extend Activity::Path()

        task task: "I am not callable!"
        task task: nested, Output(nested.outputs.keys.first, :success) => :success
        task task: B, id: "B"
      end
    end

    let(:graph)        { graph = Activity::Introspect::Graph(activity) }
    let(:start_events) { graph.start_events }
    let(:end_events)   { graph.end_events }
    let(:tasks)        { graph.tasks }

    # start_events
    it { assert_equal 1, start_events.count }
    it { assert_equal "Start.default", start_events.first[:id] }
    it { assert_equal [], start_events.first[:magnetic_to] }

    # end_events
    it { assert_equal 1, end_events.count }
    it { assert_equal "End.success", end_events.first[:id] }
    it { assert_equal [:success], end_events.first[:magnetic_to] }

    # tasks
    it { assert_equal 4, tasks.count }

    describe "#find" do
      let(:node) { graph.find("B") }
      it { node[:id].must_equal "B" }
      it { node[:magnetic_to].must_equal [:success] }
      it { node[:task].must_equal B }

      describe "with Start.default" do
        let(:node) { graph.find("Start.default") }
        it { node[:id].must_equal "Start.default" }
        it { node[:magnetic_to].must_equal [] }
        it { node[:task].must_equal activity.to_h[:circuit].to_h[:start_task] }
      end

      describe "with block" do
        let(:node) { graph.find { |node| node[:task] == B } }

        it { node[:id].must_equal "B" }
        it { node[:task].must_equal B }
        it { node[:magnetic_to].must_equal [:success] }
      end
    end
  end
end
