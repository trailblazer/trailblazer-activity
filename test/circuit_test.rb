require "test_helper"

# Currently doesn't maintain a {config} property.
class MyLibraryPipeline < Trailblazer::Activity::Circuit
  def resolve(task, _signal)
    # raise task.inspect
    # A Pipeline doesn't differentiate between different signals.
    map[task]
  end

  def to_a_FIXME
    config[start_task_id] # TODO: do at instantiation.
  end

  def self.lib_pipeline(*cfgs, **circuit_options)
    cfgs = cfgs.collect do |id, task, invoker = Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, circuit_options_to_merge = circuit_options|
      [id, task, invoker, circuit_options_to_merge]
    end

    flow_map = cfgs.collect.with_index do |(id, _), index| # FIXME: reuse Pipeline logic.
      [
        id,
        cfgs[index + 1]
      ]
    end.to_h

    # ap flow_map
    # raise

    config = cfgs.collect { |id, *args| [id, [id, *args]] }.to_h

    # raise config.inspect

    ids = flow_map.keys

    MyLibraryPipeline.new(
      config: config,
      map: flow_map, termini: ids.last, start_task_id: ids.first)
  end
end

class LibPipelineTest < Minitest::Spec
  it "ADDS on Circuit prototyping" do
    flow_map = {
      :a => {"Right" => :b, "Left" => :failure},
      :b => {"Right" => :c, "Left" => :failure},
      :c => {"Right" => :success, "Left" => :failure},
      :success => {},
      :failure => {},
    }

    # insert_before X:
    #   1. find first pointing to X, point to new
    #   2. point new to X
    def insert_before_via_ary(flow_map, inserted, before, signal_to_repoint)
      flow_ary = flow_map.to_a.collect do |id, connections|

        target = connections[signal_to_repoint]

        if target == before
          connections = connections.merge(signal_to_repoint => inserted)
        end

        [id, connections]
      end

      flow_ary = flow_ary + [[inserted, {signal_to_repoint => before}]]

      flow_ary.to_h
    end


    pp insert_after(flow_map, :d, :b, "Right")

    pp insert_before_via_hash({})
raise
    require "benchmark/ips"

    Benchmark.ips do |x|
      x.report("ary") {
        insert_before_via_ary(flow_map, :d, :b, "Right")
      }
      x.report("hash") {
        insert_before_via_hash(flow_map, :d, :b, "Right")
      }

      x.compare!
      # Comparison:
      #           hash:   799349.5 i/s
      #            ary:   521144.7 i/s - 1.53x  (± 0.00) slower

    end
  end


  it "benchmark LibPipeline vs Circuit" do
    my_exec_context = Class.new do
      def a(ctx, lib_ctx, signal)
        ctx[:seq] << :a
        return ctx, lib_ctx, signal
      end

      def b(ctx, lib_ctx, signal, **)
        ctx[:seq] << :b
        return ctx, lib_ctx, signal
      end

      def c(ctx, lib_ctx, signal, **)
        ctx[:seq] << :c
        return ctx, lib_ctx, signal
      end
    end.new

    options = [Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, {}]

    lib_pipe = MyLibraryPipeline.lib_pipeline(
      [:a, :a, *options],
      [:b, :b, *options],
      [:c, :c, *options],
      [:d, :a, *options],
      [:e, :b, *options],
      [:f, :c, *options],
    )

    circuit_pipeline = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:a, :a, *options],
      [:b, :b, *options],
      [:c, :c, *options],
      [:d, :a, *options],
      [:e, :b, *options],
      [:f, :c, *options],
    )
    ap circuit_pipeline

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(lib_pipe, {seq: []}, {}, {exec_context: my_exec_context}, nil)
    assert_equal ctx[:seq], [:a, :b, :c, :a, :b, :c]

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(circuit_pipeline, {seq: []}, {}, {exec_context: my_exec_context}, nil)
    assert_equal ctx[:seq], [:a, :b, :c, :a, :b, :c]

    require "benchmark/ips"

    Benchmark.ips do |x|
      x.report("lib_pipe") {
        ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(lib_pipe, {seq: []}, {}, {exec_context: my_exec_context}, nil)
      }

      x.report("circuit pipeline") {
        ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(circuit_pipeline, {seq: []}, {}, {exec_context: my_exec_context}, nil)
      }

      x.compare!
    end
  end

  it "what" do
    pipe = MyLibraryPipeline.lib_pipeline(
      [:a, :a],
      [:b, :b],
      [:c, :c],
    )

    assert_equal pipe.resolve(:a, nil), []
  end
end

# Test that we can build something like the Each() macro,
# where we dynamically iterate over a dataset, as if it was a circuit 1 --> 2 --> 3].
class Circuit_dynamicResolving_for_Each_Test < Minitest::Spec
  def my_task_a(ctx, lib_ctx, signal, value:, index:, **)
    ctx[:seq] << [index, value]

    return ctx, lib_ctx, signal
  end

  class MyEach
    def self.init(ctx, lib_ctx, signal, **)
      dataset = ctx.fetch(:dataset)

      return ctx, lib_ctx.merge(
        enumerator: dataset.each_with_index,
      ), signal
    end

    def self.fetch_value_from_dataset(ctx, lib_ctx, signal, enumerator:, **)
      value, index = enumerator.next

      return ctx, lib_ctx.merge(value: value, index: index), signal

    rescue StopIteration
      # DISCUSS: is there any other way to detect when an enumerator reached the end?
      return ctx, lib_ctx, "done"
    end

    def self.finished(ctx, lib_ctx, signal, **) # TODO: this isn't really necessary.
      return ctx, lib_ctx, signal
    end
  end

  it do
    config = {
      init: [:init, :init, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {}, Trailblazer::Activity::Circuit::Node::Processor, {}],
      fetch_value_from_dataset: [:fetch_value_from_dataset, :fetch_value_from_dataset, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {}, Trailblazer::Activity::Circuit::Node::Processor, {}],
      a: [:a, :my_task_a, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {exec_context: self}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {}],
      finished: [:finished, :finished, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {}, Trailblazer::Activity::Circuit::Node::Processor, {}],
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

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(
      circuit,
      {seq: [], dataset: [1,2,3]},
      {exec_context: MyEach}, # applies to all the pipeline's steps
      nil,
      runner: Trailblazer::Activity::Circuit::Node::Runner
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
      {exec_context: my_exec_context}, # applies to all the pipeline's steps
      nil
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
