require "test_helper"

class CircuitTest < Minitest::Spec
  Start = ->(options, *args, **) { options[:start] = 1; [ "to a", options, *args ] }
  A =     ->(options, *args, **) { options[:a] = 2;     [ "from a", options, *args ] }
  B =     ->(options, *args, **) { options[:b] = 3;     [ "from b", options, *args ] }
  End =  ->(options, *args, **) { options[:_end] = 4;  [ "the end", options, *args ] }

  it do
    map = {
      Start => { "to a" => A, "to b" => B },
      A => { "from a" => B },
      B => { "from b" => End}
    }

    circuit = Trailblazer::Circuit.new( map, [ End ], {} ) # FIXME: last arg

    ctx = {}

    last_signal, ctx, i, j, *bla = circuit.( ctx, 1, 2, task: Start )

    ctx.inspect.must_equal %{{:start=>1, :a=>2, :b=>3, :End=>4}}
    last_signal.must_equal "the end"
    i.must_equal 1
    j.must_equal 2
    bla.must_equal []

    # ---

    ctx = {}
    flow_options = { stack: [] }

    last_signal, ctx, i, j, *bla = circuit.( ctx, flow_options, 2, task: start, runner: MyRunner )

    flow_options.must_equal( stack: [ start, A, b, End ] )
  end

  MyRunner = ->(*args, task:, **circuit_options) do
    MyTrace.( *args, circuit_options.merge(task: task) )

    task.( *args, **circuit_options )
  end

  MyTrace = ->( options, flow_options, *args, **circuit_options ) { flow_options[:stack] << circuit_options[:task] }

  C =     ->(options, *args, **) { options[:c] = 6;     [ "from c", options, *args ] }

  let(:nestable) do

    nest_map  = {
      Start => { "to a" => C },
      C     => { "from c" => End }
    }

    nest = Trailblazer::Circuit.new( nest_map, [ End ], {} ) # FIXME: last arg

    nest_call = ->(*args, **circuit_options) {
      nest.( *args, **circuit_options.merge( task: Start ) ) }

    nest_call
  end

  let(:outer) do
    outer_map = {
      Start => { "to a" => A, "to b" => B },
      A     => { "from a" => nestable },
      nestable  => { "the end" => B },
      B     => { "from b" => End}
    }

    circuit = Trailblazer::Circuit.new( outer_map, [ End ], {} ) # FIXME: last arg
  end

  it "allows nesting circuits by using a nesting callable" do
    ctx = {}

    last_signal, ctx, i, j, *bla = outer.( ctx, 1, 2, task: Start )

    ctx.inspect.must_equal %{{:start=>1, :a=>2, :c=>6, :_end=>4, :b=>3}}
    last_signal.must_equal "the end"
    i.must_equal 1
    j.must_equal 2
    bla.must_equal []
  end

  it "allows using a custom :runner" do
    ctx = {}

    flow_options = { stack: [] }

    last_signal, ctx, flow_options, j, *bla = outer.( ctx, flow_options, 2, task: Start, runner: MyRunner )

    flow_options.must_equal( stack: [ Start, A, nestable, Start, C, End, B, End ] )
  end
end
