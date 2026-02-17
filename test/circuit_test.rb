require "test_helper"

# Test that we can build something like the Each() macro,
# where we dynamically iterate over a dataset, as if it was a circuit 1 --> 2 --> 3].
class Circuit_dynamicResolving_for_Each_Test < Minitest::Spec
  def my_task_a(ctx, lib_ctx, value:, index:, **)
    ctx[:seq] << [index, value]

    return ctx, lib_ctx, nil
  end

  class MyEach
    def self.init(ctx, lib_ctx, **)
      dataset = ctx.fetch(:dataset)

      return ctx, lib_ctx.merge(
        enumerator: dataset.each_with_index,
      ), nil
    end

    def self.fetch_value_from_dataset(ctx, lib_ctx, enumerator:, **)
      value, index = enumerator.next

      return ctx, lib_ctx.merge(value: value, index: index), nil

    rescue StopIteration
      # DISCUSS: is there any other way to detect when an enumerator reached the end?
      return ctx, lib_ctx, "done"
    end

    def self.finished(ctx, lib_ctx, **) # TODO: this isn't really necessary.
      return ctx, lib_ctx, nil
    end
  end

  it do
    config = {
      init: [:init, :init, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {exec_context: MyEach}],
      fetch_value_from_dataset: [:fetch_value_from_dataset, :fetch_value_from_dataset, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {exec_context: MyEach}],
      a: [:a, :my_task_a, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {}],
      finished: [:finished, :finished, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {exec_context: MyEach}],
    }

    map = {
        init: {nil => :fetch_value_from_dataset},
        fetch_value_from_dataset: {nil => :a, "done" => :finished},
        a: {nil => :fetch_value_from_dataset},
        finished: {}
      }

    circuit = Trailblazer::Activity::Circuit.new(
      config:     config,
      map: map,
      start_task_id: :init,
      termini: [:finished]
    )

    ctx, signal = Trailblazer::Activity::Circuit::Processor.(
      circuit,
      {seq: [], dataset: [1,2,3]},
      {},
      {exec_context: self} # applies to all the pipeline's steps
    )

    assert_equal ctx[:seq], [[0, 1], [1, 2], [2, 3]]
  end


end

# Here, we play with a "pipeline circuit" concept where there's no signal needed.
class Circuit_FasterResolving_Test < Minitest::Spec

  class MyPipelineCircuit < Struct.new(:map, :config)
    def to_a_FIXME
      config[:a]
    end

    def resolve(last_task_id, signal)
      map[last_task_id]
    end
  end

  it "prototype: pipeline resolver, with a static structure of the flow [abcde]" do
    my_exec_context = T.def_tasks(:a, :b, :c, :d, :e)

    config = {
      a: [:a, :a, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      b: [:b, :b, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      c: [:c, :c, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      d: [:d, :d, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      e: [:e, :e, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
    }

    map = {a: config[:b], b: config[:c], c: config[:d], d: config[:e]}

    my_pipeline_circuit = MyPipelineCircuit.new(map, config)

    ctx, signal = Trailblazer::Activity::Circuit::Processor.(
      my_pipeline_circuit,
      {seq: []},
      {},
      {exec_context: my_exec_context} # applies to all the pipeline's steps
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
