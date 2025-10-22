require "test_helper"

class CircuitTest < Minitest::Spec
  Steps = T.def_tasks(:a, :b, :c, :stop) # See trailblazer-core-utils, this just generates circuit-interface steps.

  let(:a) { Steps.method(:a) }
  let(:b) { Steps.method(:b) }
  let(:c) { Steps.method(:c) }
  let(:stop) { Steps.method(:stop) }

  let(:right) { Trailblazer::Activity::Right }
  let(:left) { Trailblazer::Activity::Left }
  let(:map) do
    {
      a => {right => b, left => stop},
      b => {right => c},
      c => {right => stop, left => stop},
      stop => {}
    }
  end

  let(:circuit) do
    Trailblazer::Activity::Circuit.new(map, [stop], start_task: a)
  end

  describe "Circuit#call" do
    it "with defaults" do
      ctx = {seq: []}
      flow_options = {stack: []}

      signal, ctx, flow_options = circuit.call(ctx, flow_options, {})

      assert_equal signal, Trailblazer::Activity::Right
      assert_equal CU.inspect(ctx), %({:seq=>[:a, :b, :c, :stop]})
      assert_equal CU.inspect(flow_options), %({:stack=>[]})
    end

    it "according to a task's returned signal it picks the correct next task" do
      ctx = {
        seq: [],
        a: left,
      }
      flow_options = {stack: []}

      signal, ctx, flow_options = circuit.call(ctx, flow_options, {})

      assert_equal signal, Trailblazer::Activity::Right
      assert_equal CU.inspect(ctx), %({:seq=>[:a, :stop], :a=>Trailblazer::Activity::Left})
      assert_equal CU.inspect(flow_options), %({:stack=>[]})
    end

    it "with {:start_task} starts from specified task" do
      ctx = {seq: []}
      flow_options = {stack: []}

      signal, ctx, flow_options = circuit.call(ctx, flow_options, {start_task: b})

      assert_equal signal, Trailblazer::Activity::Right
      assert_equal CU.inspect(ctx), %({:seq=>[:b, :c, :stop]})
      assert_equal CU.inspect(flow_options), %({:stack=>[]})
    end

    MyRunner = ->(task, ctx, flow_options, circuit_options) do
      MyTrace.(task, ctx, flow_options, circuit_options)

      task.(ctx, flow_options, circuit_options)
    end

    MyTrace = ->(task, ctx, flow_options, _) { flow_options[:stack] << task }

    it "with {:runner}, we can change how each task is invoked" do
      ctx = {seq: []}
      flow_options = {stack: []}

      signal, ctx, flow_options = circuit.call(ctx, flow_options, {runner: MyRunner})

      assert_equal signal, Trailblazer::Activity::Right
      assert_equal CU.inspect(ctx), %({:seq=>[:a, :b, :c, :stop]})
      assert_equal CU.inspect(flow_options), %({:stack=>[#{a}, #{b}, #{c}, #{stop}]})
    end

    it "a task can be another circuit, which is invoked with the circuit interface" do
      map = {
        a => {right => circuit},
        circuit => {right => stop},
        stop => {}
      }

      outer_circuit = Trailblazer::Activity::Circuit.new(map, [stop], start_task: a)

      ctx = {seq: []}
      flow_options = {stack: []}

      signal, ctx, flow_options = outer_circuit.call(ctx, flow_options, {})

      assert_equal signal, Trailblazer::Activity::Right
      assert_equal CU.inspect(ctx), %({:seq=>[:a, :a, :b, :c, :stop, :stop]})
      assert_equal CU.inspect(flow_options), %({:stack=>[]})
    end

    it "every {Runner.call} receives identical {circuit_options} and returned {circuit_options} are discarded" do
      my_runner = ->(task, ctx, flow_options, circuit_options) do
        ctx[:recorded] << [task, circuit_options.inspect]

        return Trailblazer::Activity::Right, ctx, flow_options,
          {ignore: "me!"} # returned {circuit_options} are discarded in Circuit's loop.
      end

      ctx = {recorded: []}
      flow_options = {stack: []}

      signal, ctx, flow_options, circuit_options = circuit.call(ctx, flow_options, original_circuit_options = {a: 9, runner: my_runner}.freeze)

      assert_equal signal, Trailblazer::Activity::Right
      assert_equal ctx[:recorded],
        [
          [a, original_circuit_options.inspect],
          [b, original_circuit_options.inspect],
          [c, original_circuit_options.inspect],
          [stop, original_circuit_options.inspect],
        ]
      assert_equal CU.inspect(flow_options), %({:stack=>[]})
    end
  end

  it "Circuit#to_h" do
    assert_equal circuit.to_h, {
      map: map,
      termini: [stop],
      start_task: a
    }
  end
end
