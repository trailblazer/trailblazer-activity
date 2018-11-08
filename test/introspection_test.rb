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
      it { node[:outgoings].inspect.must_equal(%{[#<struct Trailblazer::Activity::Introspect::Graph::Outgoing output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, task=#<Trailblazer::Activity::End semantic=:success>>, #<struct Trailblazer::Activity::Introspect::Graph::Outgoing output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, task=#<Trailblazer::Activity::End semantic=:success>>]}) }

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

    describe "#collect" do
      it do
        nodes = graph.collect { |node| node }

        nodes.size.must_equal 4

        nodes[0][:task].inspect.must_equal %{#<Trailblazer::Activity::Start semantic=:default>}
        assert_outgoings nodes[0], Activity::Right=>"I am not callable!"
        nodes[1][:task].must_equal "I am not callable!"
        assert_outgoings nodes[1], Activity::Right=>B, Activity::Left=>B
        nodes[2][:task].must_equal B
        assert_outgoings nodes[2], Activity::Right=>nodes[3].task, Activity::Left=>nodes[3].task
        nodes[3][:task].inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        assert_outgoings nodes[3], {}
      end
    end

    def assert_outputs(node, map)
      Hash[
        node.outputs.collect { |out| [out.semantic, out.signal] }
      ].must_equal(map)
    end

    def assert_outgoings(node, map)
      Hash[
        node.outgoings.collect { |out| [out.output.signal, out.task] }
      ].must_equal(map)
    end
  end
end
