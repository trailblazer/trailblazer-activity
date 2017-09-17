require "test_helper"

class CircuitTest < Minitest::Spec
  it do
    start = ->(options, *args, **) { options[:start] = 1; [ "to a", options, *args ] }
    a =     ->(options, *args, **) { options[:a] = 2;     [ "from a", options, *args ] }
    b =     ->(options, *args, **) { options[:b] = 3;     [ "from b", options, *args ] }
    _end =  ->(options, *args, **) { options[:_end] = 4;  [ "the end", options, *args ] }

    map = {
      start => { "to a" => a, "to b" => b },
      a => { "from a" => b },
      b => { "from b" => _end}
    }

    circuit = Trailblazer::Circuit.new( map, [ _end ], {} ) # FIXME: last arg

    ctx = {}

    last_signal, ctx, i, j, *bla = circuit.( ctx, 1, 2, task: start )

    ctx.inspect.must_equal %{{:start=>1, :a=>2, :b=>3, :_end=>4}}
    last_signal.must_equal "the end"
    i.must_equal 1
    j.must_equal 2
    bla.must_equal []

    # ---

    MyRunner = ->(*args, task:, **circuit_options) do
      MyTrace.( *args, circuit_options.merge(task: task) )

      task.( *args, **circuit_options )
    end

    MyTrace = ->( options, flow_options, *args, **circuit_options ) { flow_options[:stack] << circuit_options[:task] }

    ctx = {}
    flow_options = { stack: [] }

    last_signal, ctx, i, j, *bla = circuit.( ctx, flow_options, 2, task: start, runner: MyRunner )

    flow_options.must_equal( stack: [ start, a, b, _end ] )


    #---
    c =     ->(options, *args, **) { options[:c] = 6;     [ "from c", options, *args ] }
    nest_map  = {
      start => { "to_a" => c },
      c     => { "from c" => _end }
    }

    nest = Trailblazer::Circuit.new( nest_map, [ _end ], {} ) # FIXME: last arg


    outer_map = {
      start => { "to a" => a, "to b" => b },
      a     => { "from a" => nest },
      nest  => { "from nest" => b },
      b     => { "from b" => _end}
    }

  end

end
