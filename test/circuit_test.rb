require "test_helper"

class CircuitTest < Minitest::Spec
  Start   = ->((options, *args), *_circuit_options) { options[:start] = 1; ["to a", [options, *args]] }
  A       = ->((options, *args), *_circuit_options) { options[:a] = 2;     ["from a", [options, *args]] }
  B       = ->((options, *args), *_circuit_options) { options[:b] = 3;     ["from b", [options, *args]] }
  End     = ->((options, *args), *_circuit_options) { options[:_end] = 4;  ["the end", [options, *args]] }
  C       = ->((options, *args), *_circuit_options) { options[:c] = 6;     ["from c", [options, *args]] }

  it do
    map = {
      Start => {"to a" => A, "to b" => B},
      A     => {"from a" => B},
      B     => {"from b" => End}
    }

    circuit = Trailblazer::Activity::Circuit.new(map, [End], start_task: map.keys.first)

    ctx = {}

    last_signal, (ctx, i, j, *bla) = circuit.([ctx, 1, 2], task: Start)

    assert_equal CU.inspect(ctx), %{{:start=>1, :a=>2, :b=>3, :_end=>4}}
    assert_equal last_signal, "the end"
    assert_equal i, 1
    assert_equal j, 2
    assert_equal bla, []

    # ---

    ctx = {}
    flow_options = {stack: []}

    last_signal, (ctx, i, j, *bla) = circuit.([ctx, flow_options, 2], task: Start, runner: MyRunner)

    assert_equal flow_options, { stack: [Start, A, B, End] }
  end

  MyRunner = ->(task, args, **circuit_options) do
    MyTrace.(task, args, **circuit_options)

    task.(args, **circuit_options)
  end

  MyTrace = ->(task, (_options, flow_options), **_circuit_options) { flow_options[:stack] << task }

  let(:nestable) do
    nest_map = {
      Start => {"to a" => C},
      C     => {"from c" => End}
    }

    nest = Trailblazer::Activity::Circuit.new(nest_map, [End], start_task: nest_map.keys.first)

    # FIXME: FROM Activity#call
    nest_call = ->((options, flow_options, *args), **circuit_options) {
      nest.([options, flow_options, *args], **circuit_options.merge(task: Start))
    }

    nest_call
  end

  let(:outer) do
    outer_map = {
        Start => { "to a" => A, "to b" => B },
        A     => { "from a" => nestable },
        nestable  => { "the end" => B },
        B     => { "from b" => End}
    }

    Trailblazer::Activity::Circuit.new(outer_map, [End], start_task: outer_map.keys.first)
  end

  it "allows nesting circuits by using a nesting callable" do
    ctx = {}

    last_signal, (ctx, i, j, *bla) = outer.([ctx, {}, 2], task: Start)

    assert_equal CU.inspect(ctx), %{{:start=>1, :a=>2, :c=>6, :_end=>4, :b=>3}}
    assert_equal last_signal, "the end"
    assert_equal i,({})
    assert_equal j, 2
    assert_equal bla, []
  end
end
