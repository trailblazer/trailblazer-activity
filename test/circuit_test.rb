require "test_helper"

class Circuit_dynamicResolving_for_Each_Test < Minitest::Spec
  def my_task_a(ctx, value:, index:, **)
    ctx[:seq] << [index, value]

    return ctx, nil
  end

  class MyDynamicCircuit < Struct.new(:config, :map, keyword_init: true)
    def to_a_FIXME
      config[:init] # FIXME: what if dataset is empty?
    end

    def resolve(current_task_id, signal)
      if current_task_id == :a_____________

      else
        config[map[current_task_id][signal]] # DISCUSS: original Circuit#resolve logic.

      end
    end
  end

  class MyEach
    def self.init(ctx, dataset:, **)
      return ctx.merge(
        index: 0,
        last_index: dataset.size,
        ), nil
    end

    def self.fetch_value_from_dataset(ctx, index:, dataset:, **)
      value = dataset[index]

      return ctx.merge(value: value), nil
    end

    def self.increase_index(ctx, index:, dataset:, last_index:, **)
      index += 1
      return ctx, "done" if index == last_index
      return ctx.merge(index: index)
    end

    def self.finished(ctx, **)
      return ctx, nil
    end
  end

  it do
    config = {
      init: [:init, :init, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {exec_context: MyEach}],
      fetch_value_from_dataset: [:fetch_value_from_dataset, :fetch_value_from_dataset, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {exec_context: MyEach}],
      a: [:a, :my_task_a, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
      increase_index: [:increase_index, :increase_index, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {exec_context: MyEach}],
      finished: [:finished, :finished, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {exec_context: MyEach}],
    }

    map = {
        init: {nil => :fetch_value_from_dataset},
        fetch_value_from_dataset: {nil => :a},
        a: {nil => :increase_index},
        increase_index: {nil => :fetch_value_from_dataset, "done" => :finished},
        finished: {}
      }

    circuit = MyDynamicCircuit.new(
      # map:        map,
      # start_task_id: :a,
      # termini:    [:e],
      config:     config,
      map: map,
    )

    ctx, signal = Trailblazer::Activity::Circuit::Processor.(
      circuit,
      {seq: [], dataset: [1,2,3]},

      exec_context: self # applies to all the pipeline's steps
    )

    assert_equal ctx[:seq], [[0, 1], [1, 2], [2, 3]]
  end


end

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
