require "test_helper"

class IntrospectionTest < Minitest::Spec

  describe "Introspect::Graph" do
    let(:graph) { Activity::Introspect::Graph(nested_activity) }

    describe "#find" do
      let(:node) { graph.find(:B) }
      it { node[:id].must_equal :B }
      it { assert_outputs(node, success: Activity::Right) }
      it { node[:task].must_equal implementing.method(:b) }
      it { node[:outgoings].inspect.must_equal(%{[#<struct Trailblazer::Activity::Introspect::Graph::Outgoing output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, task=#{bc.inspect}>]}) }
      it { node[:data].inspect.must_equal %{{:more=>true}} }

      describe "with Start.default" do
        let(:node) { graph.find("Start.default") }
        it { node[:id].must_equal "Start.default" }
        it { assert_outputs(node, success: Activity::Right) }
        it { node[:task].must_equal nested_activity.to_h[:circuit].to_h[:start_task] }
      end

      describe "with block" do
        let(:node) { graph.find { |node| node[:task] == implementing.method(:b) } }

        it { node[:id].must_equal :B }
        it { node[:task].must_equal implementing.method(:b) }
        it { assert_outputs(node, success: Activity::Right) }
      end
    end

    describe "#collect" do
      it "provides 1-arg {node}" do
        nodes = graph.collect { |node| node }

        nodes.size.must_equal 5

        nodes[0][:task].inspect.must_equal %{#<Trailblazer::Activity::Start semantic=:default>}
        assert_outgoings nodes[0], Activity::Right=>implementing.method(:b)
        nodes[1][:task].must_equal implementing.method(:b)
        assert_outgoings nodes[1], Activity::Right=>bc
        nodes[2][:task].must_equal bc
        assert_outgoings nodes[2], bc.to_h[:outputs][0].signal => nodes[3].task
        nodes[3][:task].must_equal implementing.method(:f)
        assert_outgoings nodes[3], Activity::Right => nested_activity.to_h[:outputs][0].signal
        nodes[4][:task].inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        assert_outgoings nodes[4], {}
      end

      it "provides 2-arg {node, index}" do
        nodes = graph.collect { |node, i| [node, i] }

        nodes.size.must_equal 5

        nodes[0][0][:task].inspect.must_equal %{#<Trailblazer::Activity::Start semantic=:default>}
        nodes[0][1].must_equal 0
        nodes[4][0][:task].inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        nodes[4][1].must_equal 4
      end
    end

    describe "#stop_events" do
      it { graph.stop_events.inspect.must_equal %{[#<Trailblazer::Activity::End semantic=:success>]} }
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
