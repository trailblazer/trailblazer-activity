require "test_helper"

class IntrospectionTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

  let(:activity) do
    nested = bc

    activity = Module.new do
      extend Activity[]
      task task: A
      task task: nested, Output(nested.outputs.keys.first, :success) => :success
      task task: D, id: "D"
    end
  end

  let(:bc) do
    activity = Module.new do
      extend Activity[]
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

  describe "::find" do
    it "returns task" do
      activity = Module.new do
        extend Activity[]

        task task: "I am not callable!"
        task B
      end

      Activity::Introspect.find(activity) { |task, _| task.inspect =~ /callable!/ }.first.must_equal "I am not callable!"
    end
  end
end
