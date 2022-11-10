require "test_helper"

class IntrospectionTest < Minitest::Spec
  describe "Introspect.find_path" do
    it "#find_path" do
      b_activity = nested_activity() # [B, [B, C], E]
      activity   = nested_activity(flat_activity: b_activity, d_id: :Delete) # [B, Delete=[B, D=[B, C], E], E]

      #@ find top-activity which returns a special Node.
      node, host_activity, graph = Trailblazer::Activity::Introspect.find_path(activity, [])
      assert_equal node.class, Trailblazer::Activity::Introspect::TaskMap::TaskAttributes
      assert_equal node[:task], activity
      assert_equal host_activity, Trailblazer::Activity::TaskWrap.container_activity_for(activity)

      #@ one element path
      node, host_activity, graph = Trailblazer::Activity::Introspect.find_path(activity, [:E])
      assert_equal node.class, Trailblazer::Activity::Introspect::TaskMap::TaskAttributes
      assert_equal node[:task], Implementing.method(:f)
      assert_equal host_activity, activity

      #@ nested element
      node, host_activity, _graph = Trailblazer::Activity::Introspect.find_path(activity, [:Delete, :D, :C])
      assert_equal node.class, Trailblazer::Activity::Introspect::TaskMap::TaskAttributes
      assert_equal node[:task], Implementing.method(:c)
      assert_equal host_activity, flat_activity

      #@ non-existent element
      assert_nil Trailblazer::Activity::Introspect.find_path(activity, [:c])
      assert_nil Trailblazer::Activity::Introspect.find_path(activity, [:Delete, :c])
    end
  end

  describe "Introspect.TaskMap()" do
    it "exposes Hash API" do
      task_map = Activity::Introspect.TaskMap(flat_activity) # [B, C]

    #@ #[] finds by task
      attributes = task_map[Implementing.method(:b)]
      assert_equal attributes[:id],   :B
      assert_equal attributes[:task], Implementing.method(:b)

    #@ #fetch finds by task
      assert_equal task_map.fetch(Implementing.method(:b))[:id], :B

    #@ #find_by_id
      # assert_equal task_map.find_by_id(:B)[:id], :B

    #@ non-existent
      assert_equal task_map[nil], nil
      assert_raises KeyError do task_map.fetch(nil) end
    end
  end

  describe "Introspect::Graph" do
    let(:graph) { Activity::Introspect::Graph(nested_activity) }

    describe "#find" do
      let(:node) { graph.find(:B) }
      it { expect(node[:id]).must_equal :B }
      it { assert_outputs(node, success: Activity::Right) }
      it { expect(node[:task]).must_equal implementing.method(:b) }
      it { expect(node[:outgoings].inspect).must_equal(%{[#<struct Trailblazer::Activity::Introspect::Graph::Outgoing output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, task=#{bc.inspect}>]}) }
      it { expect(node[:data].inspect).must_equal %{{:more=>true}} }

      describe "with Start.default" do
        let(:node) { graph.find("Start.default") }
        it { expect(node[:id]).must_equal "Start.default" }
        it { assert_outputs(node, success: Activity::Right) }
        it { expect(node[:task]).must_equal nested_activity.to_h[:circuit].to_h[:start_task] }
      end

      describe "with block" do
        let(:node) { graph.find { |node| node[:task] == implementing.method(:b) } }

        it { expect(node[:id]).must_equal :B }
        it { expect(node[:task]).must_equal implementing.method(:b) }
        it { assert_outputs(node, success: Activity::Right) }
      end
    end

    describe "#collect" do
      it "provides 1-arg {node}" do
        nodes = graph.collect { |node| node }

        expect(nodes.size).must_equal 5

        expect(nodes[0][:task].inspect).must_equal %{#<Trailblazer::Activity::Start semantic=:default>}
        assert_outgoings nodes[0], Activity::Right => implementing.method(:b)
        expect(nodes[1][:task]).must_equal implementing.method(:b)
        assert_outgoings nodes[1], Activity::Right => bc
        expect(nodes[2][:task]).must_equal bc
        assert_outgoings nodes[2], bc.to_h[:outputs][0].signal => nodes[3].task
        expect(nodes[3][:task]).must_equal implementing.method(:f)
        assert_outgoings nodes[3], Activity::Right => nested_activity.to_h[:outputs][0].signal
        expect(nodes[4][:task].inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        assert_outgoings nodes[4], {}
      end

      it "provides 2-arg {node, index}" do
        nodes = graph.collect { |node, i| [node, i] }

        expect(nodes.size).must_equal 5

        expect(nodes[0][0][:task].inspect).must_equal %{#<Trailblazer::Activity::Start semantic=:default>}
        expect(nodes[0][1]).must_equal 0
        expect(nodes[4][0][:task].inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        expect(nodes[4][1]).must_equal 4
      end
    end

    describe "#stop_events" do
      it { expect(graph.stop_events.inspect).must_equal %{[#<Trailblazer::Activity::End semantic=:success>]} }
    end

    def assert_outputs(node, map)
      expect(Hash[
        node.outputs.collect { |out| [out.semantic, out.signal] }
      ]).must_equal(map)
    end

    def assert_outgoings(node, map)
      expect(Hash[
        node.outgoings.collect { |out| [out.output.signal, out.task] }
      ]).must_equal(map)
    end
  end
end
