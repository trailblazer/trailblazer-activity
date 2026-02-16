require "test_helper"

# Here, we play with a "pipeline circuit" concept where there's no signal needed.
class Circuit_FasterResolving_Test < Minitest::Spec
  def my_task_a(ctx, **)
    ctx[:seq] << :a

    return ctx, nil
  end
  def my_task_b(ctx, **)
    ctx[:seq] << :b

    return ctx, nil
  end
  def my_task_c(ctx, **)
    ctx[:seq] << :c

    return ctx, nil
  end
  def my_task_d(ctx, **)
    ctx[:seq] << :d

    return ctx, nil
  end
  def my_task_e(ctx, **)
    ctx[:seq] << :e

    return ctx, nil
  end

  class MyPipelineCircuit < Struct.new(:map, :config)
    def to_a_FIXME
      config[:a]
    end

    def resolve(last_task_id, signal)
      map[last_task_id]
    end
  end

  it "prototype: pipeline resolver, with a static structure of the flow [abcde]" do
    config = {
      a: [:a, :my_task_a, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      b: [:b, :my_task_b, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      c: [:c, :my_task_c, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      d: [:d, :my_task_d, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      e: [:e, :my_task_e, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
    }

    map = {a: config[:b], b: config[:c], c: config[:d], d: config[:e]}

    my_pipeline_circuit = MyPipelineCircuit.new(map, config)

    ctx, signal = Trailblazer::Activity::Circuit::Processor.(
      my_pipeline_circuit,
      {seq: []},

      exec_context: self # applies to all the pipeline's steps
    )

    assert_equal CU.inspect(ctx), %({:seq=>[:a, :b, :c, :d, :e]})

    # This code creates a normal Circuit, then we benchmark those.
    # Current status: =========> the above is  1.1x faster.
=begin
    map = {
      a: {nil => :b},
      b: {nil => :c},
      c: {nil => :d},
      d: {nil => :e},
    }

    circuit = Trailblazer::Activity::Circuit.new(
      map:        map,
      start_task_id: :a,
      termini:    [:e],
      config:     config,
    )

    ctx, signal = Trailblazer::Activity::Circuit::Processor.(
      circuit,
      {seq: []},

      exec_context: self # applies to all the pipeline's steps
    )

    assert_equal CU.inspect(ctx), %({:seq=>[:a, :b, :c, :d, :e]})

    require "benchmark/ips"

    Benchmark.ips do |x|
      x.report("circuit with pipe") {
        ctx, signal = Trailblazer::Activity::Circuit::Processor.(
          my_pipeline_circuit,
          {seq: []},

          exec_context: self # applies to all the pipeline's steps
        )
      }

      x.report( "Circuit") {
        ctx, signal = Trailblazer::Activity::Circuit::Processor.(
          circuit,
          {seq: []},

          exec_context: self # applies to all the pipeline's steps
        )
      }

      x.compare!
    end

   #  Comparison:
   # circuit with pipe:   319267.1 i/s
   #           Circuit:   297489.3 i/s - 1.07x  (± 0.00) slower
=end
  end
end
