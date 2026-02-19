require "test_helper"

  module Trailblazer
    class Context < Struct.new(:shadowed, :mutable)
      def []=(key, value)
        mutable[key] = value

        # @to_h[key] = value
      end

      def [](key)
        # raise
        mutable[key] || shadowed[key] # FIXME.
      end

      def merge(variables)
        # raise
        # puts variables.inspect
        Context.new(shadowed, mutable.merge(variables))
      end

      def decompose
        return shadowed, mutable
      end

      def to_h
        # return @to_h
        shadowed.to_h.merge(mutable) # DISCUSS: shadowed.to_h we only should do once, at instantiation!
      end

      def to_hash # implicit conversion to Hash.
        to_h
      end
    end

    def self.Context(shadowed)
      Context.new(shadowed, {})
    end
  end


  class IO___
    # Lib interface.
    def init_aggregate(ctx, lib_ctx, signal, **)
      lib_ctx[:aggregate] = {}

      return ctx, lib_ctx, signal
    end

    # Lib interface.
    def add_value_to_aggregate(ctx, lib_ctx, signal, value:, aggregate:, **)
      lib_ctx[:aggregate] = aggregate.merge(value)

      return ctx, lib_ctx, signal
    end

    # Lib interface.
    def save_original_application_ctx(ctx, lib_ctx, signal, **)
      lib_ctx[:original_application_ctx] = ctx # the "outer ctx".

      return ctx, lib_ctx, signal
    end

    # Lib interface.
    def swap___(ctx, lib_ctx, original_application_ctx:, aggregate:, **)
      # new_application_ctx = original_application_ctx.merge(aggregate) # DISCUSS: how to write on outer ctx?
      aggregate.each do |k, v|
        original_application_ctx[k] = v # FIXME: should we use Context#merge here? do we want a new ctx?

      end

      new_ctx = original_application_ctx

      return new_ctx, lib_ctx, nil
    end


    def create_application_ctx(ctx, lib_ctx, aggregate:, **)
      new_ctx = Trailblazer::Context(aggregate)

      return new_ctx, lib_ctx, nil
    end
  end


# TODO:
# 1. SOMETHINg like Pipe::Input, nested pipe, check out how to use a work ctx
# [2. done] do we need pipelines?
# 3. runtime tw
# 4. show how task can be replaced at runtime, e.g. for Nested
# 5. how to call with kwargs, e.g. in Rescue?
# 6. "scopes" for tracing? E.g. "only trace business steps"
# 7. try saving memory by providing often-used Pipes, e.g. for IO?
# 8. how would we change the "circuit options" from a step? ===> change :start_task
# 9. does invoker.call need kwargs?
# [10. done] BUG: when all tasks are the same proc and the last is the terminus, only the first is run. ===> use ids, we got them, anyway.
# 11. should circuit_options be a positional arg?
# [12. done] don't repeat io.new as context, use automatic passing [done]
# 13. termini IDs in map when using nesting

class RunnerInvokerTest < Minitest::Spec
  it "circuit_options, depth-only" do
    def capture_task(id:)
      ->(ctx, lib_ctx, circuit_options, **) do
        ctx[:captured] << [id, circuit_options[:exec_context], circuit_options[:lib_exec_context]].compact
        return ctx, lib_ctx, nil
      end
    end

    model_pipe = lib_pipeline(
      [:input, capture_task(id: 1), Trailblazer::Activity::Task::Invoker::CircuitInterface],
      [:model, capture_task(id: 2), Trailblazer::Activity::Task::Invoker::CircuitInterface],
      [:output, capture_task(id: 3), Trailblazer::Activity::Task::Invoker::CircuitInterface],
    )

    validate_input_pipe = lib_pipeline(
      [:input, capture_task(id: 4), Trailblazer::Activity::Task::Invoker::CircuitInterface],
      [:exec_on__parent, capture_task(id: 5), Trailblazer::Activity::Task::Invoker::CircuitInterface], # exec on original ctx!
    )

    validate_pipe = lib_pipeline(
      [:Validate_input, validate_input_pipe, Trailblazer::Activity::Circuit::Processor, {lib_exec_context: "Validate::Input"}],
      [:validate, capture_task(id: 6), Trailblazer::Activity::Task::Invoker::CircuitInterface],
    )

    create_pipe = lib_pipeline(
      [:Model, model_pipe, Trailblazer::Activity::Circuit::Processor],
      [:Validate, validate_pipe, Trailblazer::Activity::Circuit::Processor],
    )

    # As we pass in exec_context: as a kwarg, it's passed to all siblings etc.
    ctx, _ = Trailblazer::Activity::Circuit::Processor.(create_pipe, {captured: []}, {}, {exec_context: "Object"}, nil)
    assert_equal ctx[:captured], [[1, "Object"], [2, "Object"], [3, "Object"], [4, "Object", "Validate::Input"], [5, "Object", "Validate::Input"], [6, "Object"]]

# FIXME: new test case.
puts
    create_pipe = lib_pipeline(
      [:Model, model_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: "Model"}],
      [:Validate, validate_pipe, Trailblazer::Activity::Circuit::Processor],
    )

    ctx, _ = Trailblazer::Activity::Circuit::Processor.(create_pipe, {captured: []}, {}, {exec_context: "Object"}, nil)
    assert_equal ctx[:captured], [[1, "Model"], [2, "Model"], [3, "Model"], [4, "Object", "Validate::Input"], [5, "Object", "Validate::Input"], [6, "Object"]]
  end

  module Fixtures
    class Create
      # Step interface.
      def model(ctx, params:, **kws)
        ctx[:spam] = false
        ctx[:model] = "Object #{params[:id]} / #{kws.inspect}"
      end

      # Add params[:slug],
      def my_model_input(ctx, params:, slug:, **)
        {
          params: params.merge(slug: slug)
        }
      end

      # In() => MoreModelInput
      class MoreModelInput
        # Step interface.
        def self.call(ctx, slug:, **)
          {
            more: slug
          }
        end
      end

      # Out() => [:model]
      # Step interface.
      def my_model_output(ctx, model:, **)
        {
          model: model
        }
      end
    end

    class Validate
      # Step interface.
      def run_checks(ctx, params:, model:, **)
        if params[:song]
          return true
        else
          ctx[:errors] = [model, :song]
          return false
        end
      end

      # Step interface.
      def title_length_ok?(ctx, params:, **)
        return false unless params[:song][:title]

        return true
      end
    end

    class Save
      # Step interface.
      def self.call(ctx, model:, **)
        ctx[:save] = model
      end
    end

    def self.pipeline_circuit(*args)
      Trailblazer::Activity::Circuit::Builder.Pipeline(*args)
    end

    def self.fixtures
      io = IO___.new

      # In() => :my_model_input
      my_model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:invoke_instance_method, :my_model_input, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: Create.new}],
        [:add_value_to_aggregate, :add_value_to_aggregate],
      )

      more_model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:invoke_callable, Create::MoreModelInput, Trailblazer::Activity::Task::Invoker::StepInterface],
        [:add_value_to_aggregate, :add_value_to_aggregate],
      )

      my_model_output_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:invoke_instance_method, :my_model_output, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: Create.new}],
        [:add_value_to_aggregate, :add_value_to_aggregate],
      )

      # !!! requires: {exec_context: io}
      model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:save_original_application_ctx, :save_original_application_ctx],
        [:init_aggregate, :init_aggregate],
        [:my_model_input, my_model_input_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:aggregate]}],     # user filter.
        [:more_model_input, more_model_input_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:aggregate]}], # user filter.
        [:create_application_ctx, :create_application_ctx, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {}],
      )

      # !!! requires: {exec_context: io}
      model_output_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:init_aggregate, :init_aggregate],
        [:my_model_output, my_model_output_pipe, Trailblazer::Activity::Circuit::Processor],     # user filter.
        [:swap___, :swap___, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {}],
      )

    #{ } how to handle signal?"

      model_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:input, model_input_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {exec_context: io, copy_to_outer_ctx: [:original_application_ctx], return_outer_signal: true}], # change {:application_ctx}.

        [:invoke_instance_method, :model, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: Create.new}],
        [:compute_binary_signal, Trailblazer::Activity::Circuit::Step::ComputeBinarySignal, Trailblazer::Activity::Task::Invoker::LibInterface],
        [:output, model_output_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {exec_context: io, return_outer_signal: true}],
      # [:bla, ->(ctx, lib_ctx, signal, **) { raise signal.inspect }, Trailblazer::Activity::Task::Invoker::LibInterface::A____withSignal_FIXME],
      )

      run_checks_pipe = pipeline_circuit(
        [:invoke_instance_method, :run_checks, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod], # FIXME: we're currenly assuming that exec_context is passed down.
        [:compute_binary_signal, Trailblazer::Activity::Circuit::Step::ComputeBinarySignal, Trailblazer::Activity::Task::Invoker::LibInterface],
      )

      title_length_ok_pipe = pipeline_circuit(
        [:invoke_instance_method, :title_length_ok?, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod],
        [:compute_binary_signal, Trailblazer::Activity::Circuit::Step::ComputeBinarySignal, Trailblazer::Activity::Task::Invoker::LibInterface],
      )

      validate_circuit, validate_termini = Trailblazer::Activity::Circuit::Builder.Circuit(
        [:run_checks, run_checks_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {},
          {Trailblazer::Activity::Right => :title_length_ok?, Trailblazer::Activity::Left => :failure}
        ],
        [:title_length_ok?, title_length_ok_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {},
          {Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure}
        ],
        [:success, Trailblazer::Activity::Terminus::Success.new(semantic: :success)],
        [:failure, Trailblazer::Activity::Terminus::Failure.new(semantic: :failure)],

        termini: [:success, :failure]
      )

      save_pipe = pipeline_circuit(
        [:invoke_callable, Save, Trailblazer::Activity::Task::Invoker::StepInterface],
        [:compute_binary_signal, Trailblazer::Activity::Circuit::Step::ComputeBinarySignal, Trailblazer::Activity::Task::Invoker::LibInterface],
      )

      create_circuit, create_termini = Trailblazer::Activity::Circuit::Builder.Circuit(
        [:Model,    model_pipe, Trailblazer::Activity::Circuit::Processor::Scoped,      {exec_context: Create.new.freeze},
          {Trailblazer::Activity::Right => :Validate, Trailblazer::Activity::Left => :failure}
        ], # TODO: circuit_options should be set outside of Create, in the canonical invoke.
        [:Validate, validate_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {exec_context: Validate.new.freeze},
          {validate_termini[:success] => :Save, validate_termini[:failure] => :failure}
        ],
        [:Save,     save_pipe, Trailblazer::Activity::Circuit::Processor::Scoped,       {},
          {Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure}
        ], # check that we don't have circuit_options anymore here?
        [:success, Trailblazer::Activity::Terminus::Success.new(semantic: :success)],
        [:failure, Trailblazer::Activity::Terminus::Failure.new(semantic: :failure)],

        termini: [:success, :failure]
      )

      return create_circuit, create_termini, model_input_pipe, model_output_pipe, validate_termini
    end
  end

  it "wrap_runtime prototyping" do
    create_circuit, create_termini, _, _, validate_termini = Fixtures.fixtures

    ctx = {params: {song: nil}, slug: 666}

    class Trace
      def self.capture_before(ctx, lib_ctx, circuit_options, signal, stack:, **) # FIXME: we need circuit_options for the {:task}.
        task = circuit_options[:task] or raise

        stack << [:before, task, ctx.to_h.inspect]

        return ctx, lib_ctx, signal
      end

      def self.capture_after(ctx, lib_ctx, circuit_options, signal, stack:, **) # FIXME: we need circuit_options for the {:task}.
        task = circuit_options[:task] or raise

        stack << [:after, task, ctx.to_h.inspect, signal]

        return ctx, lib_ctx, signal
      end
    end

    # Since a Processor is only called for Circuit instances, we can simply
    # extend the circuit at runtime.
    class WrapRuntime < Struct.new(:original_invoker)
      def call(circuit, ctx, lib_ctx, circuit_options, signal)
        wrap_runtime = circuit_options.fetch(:wrap_runtime)

        config = circuit.config

        # create a new circuit that has a nested tW pipe for each original task.
        new_circuit_config = config.collect do |id, (_, task, invoker, circuit_options)|
          if task.is_a?(Trailblazer::Activity::Circuit)
            invoker = WrapRuntime.new(invoker) # apply recursion.
          end

          task_cfg = [id, task, invoker, circuit_options]

          # TODO: using Pipeline is probably not fast at runtime.
          # TODO: apply ADDS insertion instructions here
          tw_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
            [:capture_before, :capture_before, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME_and_Circuitoptions, {exec_context: Trace}],
            task_cfg,
            [:capture_after, :capture_after, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME_and_Circuitoptions, {exec_context: Trace}],
          )
# TODO: where and when should we set {:task} on circuit_options?
          [id, [id, tw_pipe, Trailblazer::Activity::Circuit::Processor, {task: id}]] # Note that we're NOT using a scoped Processor here, we don't need it for any wrap_runtime
        end.to_h

  # pp new_circuit_config
  #         raise

        circuit_class = circuit.class

        new_circuit = circuit_class.new(
          **circuit.to_h,
          config: new_circuit_config,
        )

        original_invoker.(new_circuit, ctx, lib_ctx, circuit_options, signal)
      end
    end

    # original_config = create_circuit.config[:Model]

    # id = :Model
    # model_tw_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
    #   [:capture_before, :capture_before, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {exec_context: Trace, task: id}],
    #   original_config, # FIXME: how to handle signal here?
    # )

    # pp Trailblazer::Activity::Circuit::Processor::Scoped.(model_tw_pipe, {slug: "0x1", params: {song: {}}}, {stack: []}, {})






    # my_task_wrap_runtime_processor = WrapRuntime.(Trailblazer::Activity::Circuit::Processor::Scoped)

    # validation error:
    ctx, lib_ctx, signal = WrapRuntime.new(Trailblazer::Activity::Circuit::Processor::Scoped).(create_circuit, ctx, {stack: []}, {
        wrap_runtime: Hash.new(),
        # emit_signal: true,
      },
      nil
    )

    assert_equal ctx, {:params=>{:song=>nil}, slug: 666, :model=>"Object  / {:more=>666}", :errors=>["Object  / {:more=>666}", :song]}
    assert_equal lib_ctx.keys, [:stack]
    assert_equal signal, create_termini[:failure]

    # assert_equal ap(lib_ctx[:stack].ai, ruby19_syntax: true), %()

    # ap lib_ctx[:stack]

    assert_equal lib_ctx[:stack], [
      [:before, :Model, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :save_original_application_ctx, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :save_original_application_ctx, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :init_aggregate, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :init_aggregate, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :my_model_input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :invoke_instance_method, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :invoke_instance_method, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :add_value_to_aggregate, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :add_value_to_aggregate, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:after, :my_model_input, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :more_model_input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :invoke_callable, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :invoke_callable, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :add_value_to_aggregate, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :add_value_to_aggregate, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:after, :more_model_input, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :create_application_ctx, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :create_application_ctx, "{:params=>{:song=>nil, :slug=>666}, :more=>666}", nil],
      [:after, :input, "{:params=>{:song=>nil, :slug=>666}, :more=>666}", nil],
      [:before, :invoke_instance_method, "{:params=>{:song=>nil, :slug=>666}, :more=>666}"],
      [:after, :invoke_instance_method, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", nil],
      [:before, :compute_binary_signal, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
      [:after, :compute_binary_signal, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],
      [:before, :output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
      [:before, :init_aggregate, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
      [:after, :init_aggregate, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],
      [:before, :my_model_output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
      [:before, :invoke_instance_method, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
      [:after, :invoke_instance_method, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", nil],
      [:before, :add_value_to_aggregate, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
      [:after, :add_value_to_aggregate, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", nil],
      [:after, :my_model_output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", nil],
      [:before, :swap___, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
      [:after, :swap___, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}", nil],
      [:after, :output, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],
      [:after, :Model, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],
      [:before, :Validate, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}"],
      [:before, :run_checks, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}"],
      [:before, :invoke_instance_method, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}"],
      [:after, :invoke_instance_method, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", nil],
      [:before, :compute_binary_signal, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}"],
      [:after, :compute_binary_signal, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", Trailblazer::Activity::Left],
      [:after, :run_checks, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", Trailblazer::Activity::Left],
      [:before, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}"],
      [:after, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_termini[:failure]],
      [:after, :Validate, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_termini[:failure]],
      [:before, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}"],
      [:after, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", create_termini[:failure]]]

  end

  def lib_pipeline(*args, **kws)
    Trailblazer::Activity::Circuit::Builder.Pipeline(*args, **kws)
  end

  it "Signal Pipeline / signal scoping" do
    my_tw = Class.new do
      def self.a(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :a

        return ctx, lib_ctx, signal
      end

      def self.b(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :b

        return ctx, lib_ctx, signal
      end

      def self.c(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :c

        return ctx, lib_ctx, signal
      end

      def self.d(ctx, lib_ctx, signal, **)
        lib_ctx[:seq] << :d

        return ctx, lib_ctx, signal
      end

      def self.my_signal_step(ctx, lib_ctx, circuit_options)
        return ctx, lib_ctx.merge(seq: lib_ctx[:seq] + [:my_signal_step]), Trailblazer::Activity::Right # returning Right here "breaks" the "next task resolving" in an unconfigured world.
      end

      def self.my_left_signal_step(ctx, lib_ctx, circuit_options)
        seq = lib_ctx[:seq] + [:my_left_signal_step]

        return ctx, lib_ctx.merge(seq: seq), Trailblazer::Activity::Left # FIXME: merge doesn't work!
      end
    end

    invoke_instance_method_lib_circuit = lib_pipeline(
      [:d, :d, ],
      [:my_left_signal_step, :my_left_signal_step, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod],
      exec_context: my_tw
    )

  # Out => [:seq], Out() => <signal>
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(invoke_instance_method_lib_circuit, {}, {seq: []}, {copy_to_outer_ctx: [:seq]}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:d, :my_left_signal_step]})
    assert_equal signal, Trailblazer::Activity::Left # signal from {my_left_signal_step}.

  # Out => [:seq], discard inner <signal>
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(invoke_instance_method_lib_circuit, {}, {seq: []}, {copy_to_outer_ctx: [:seq], return_outer_signal: true}, Object)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:d, :my_left_signal_step]})
    assert_equal signal, Object # signal from {my_left_signal_step} got discarded.



  # Nesting
    task_wrap_for_model_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],
      [:call_model, invoke_instance_method_lib_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq]}], # we want this signal!
      [:c, :c],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(task_wrap_for_model_pipe, {}, {seq: []}, {copy_to_outer_ctx: [:seq], exec_context: my_tw}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b, :d, :my_left_signal_step, :c]})
    assert_equal signal, Trailblazer::Activity::Left

  # Nesting with two signal producers on the same branch/level.
  # the second wins with Right.
    task_wrap_for_model_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],
      [:call_model, invoke_instance_method_lib_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq]}], # we want this signal!
      [:c, :c],
      [:output, :my_signal_step, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod], # this signal wins, because it's not configured!
      [:d, :d],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(task_wrap_for_model_pipe, {}, {seq: []}, {copy_to_outer_ctx: [:seq], exec_context: my_tw}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b, :d, :my_left_signal_step, :c, :my_signal_step, :d]})
    assert_equal signal, Trailblazer::Activity::Right


  # Nesting with two signal producers on the same branch/level.
  # the second's Right signal gets discarded.
    output_pipe = lib_pipeline(
      [:emit_right, :my_signal_step, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod],
    )

    task_wrap_for_model_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],
      [:call_model, invoke_instance_method_lib_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq]}], # we want this signal!
      [:c, :c],
      [:output, output_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:seq], return_outer_signal: true}],
      [:d, :d],
    )

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(task_wrap_for_model_pipe, {}, {seq: []}, {copy_to_outer_ctx: [:seq], exec_context: my_tw}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b, :d, :my_left_signal_step, :c, :my_signal_step, :d]})
    assert_equal signal, Trailblazer::Activity::Left


    raise


    signal_pipe = lib_pipeline(
      [:a, :a, ],
      [:b, :b],



      [:my_signal_step, :my_signal_step, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod],
      [:c, :c],
      exec_context: my_tw
    )



    library_pipeline = MyLibraryPipeline.new(**signal_pipe.to_h)

    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(library_pipeline, {}, {seq: []}, {}, nil)

    assert_equal CU.inspect(ctx), %({})
    assert_equal CU.inspect(lib_ctx), %({:seq=>[:a, :b]})
    assert_equal signal, Trailblazer::Activity::Right
  end

require "benchmark/ips"
  it do
    create_circuit, create_termini, model_input_pipe, model_output_pipe = Fixtures.fixtures()


# TEST I/O

#  Benchmark.ips do |x|
#    x.report("cix") {
  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(model_input_pipe,
    {params: {song: {}}, noise: true, slug: "0x666"},
    {},
    # exec_context: create_instance = Create.new,
    {
      exec_context:  IO___.new,
      copy_to_outer_ctx: [:original_application_ctx].freeze,

    },
    nil
  )
 # }
 #   x.compare! # 43.6 -45.2k
 # end

   # Context():
   #   1.) 25.4k
   #   2.) 36.7k (simple Context)

  # raise ctx.inspect
  assert_equal ctx.class, Trailblazer::Context # our In pipe's creation!
  assert_equal ctx[:more], "0x666" # the more_model_input was called.
  assert_equal lib_ctx[:original_application_ctx].class, Hash # the OG ctx is a Hash.
  assert_equal lib_ctx.keys, [:original_application_ctx]
  assert_equal CU.inspect(ctx), %(#<struct Trailblazer::Context shadowed={:params=>{:song=>{}, :slug=>\"0x666\"}, :more=>\"0x666\"}, mutable={}>)

  # this is what happens in the actual {:model} step.
  ctx[:model] = Object

  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(model_output_pipe,
    ctx,
    lib_ctx,
    {copy_to_outer_ctx: [],
        exec_context: IO___.new,},
    nil
  )

# FIXME!!!!!!!!!!!!!!!!!!!!!! original_application_ctx shooouldn't contain {model}?
  assert_equal ctx.inspect, %({:params=>{:song=>{}}, :noise=>true, :slug=>"0x666", :model=>Object})















  ctx = {params: {song: nil}, slug: "0x666"}
  # create_ctx = {
  #   # exec_context:     Create.new,
  #   application_ctx:  ctx
  # }

puts "ciiii"
  # validation error:
  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, ctx, {}, {}, nil)

  assert_equal ctx, {:params=>{:song=>nil}, slug: "0x666", :model=>"Object  / {:more=>\"0x666\"}", :errors=>["Object  / {:more=>\"0x666\"}", :song]}
  assert_equal lib_ctx.keys, []
  assert_equal signal, create_termini[:failure]

  # success:
  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"}, {}, {}, nil)

  assert_equal ctx, {:params=>{:song=>{title: "Uwe"}, id: 1}, slug: "0x666", :model=>"Object 1 / {:more=>\"0x666\"}", :save=>"Object 1 / {:more=>\"0x666\"}"}
  assert_equal lib_ctx.keys, []
  assert_equal signal, create_termini[:success]

  def call_me(create_circuit)
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"}, {}, {}, nil)
  end

  Benchmark.ips do |x|
    x.report("cix") {
      ctx, signal = call_me(create_circuit)
    }
    x.compare!
  end
end
  # 1.
  #   5.648k vs 19.834k how is that so slow?
  # 2. circuit map now is based on ID symbols and not [id, task, invoker, ...] which was obviously very slow to compute the key every time
  #   21.847k that is a lot faster!

  # save_pipe = [
  #   a = [:input, Model___Input, Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],

  #   b= [:invoke_callable, Save, Trailblazer::Activity::Task::Invoker::StepInterface, {}],
  #   c= [:compute_binary_signal, Trailblazer::Activity::Circuit::Step::ComputeBinarySignal, Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],

  #   d =[:output, Model___Output, Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],
  # ]


  # save_circuit = {
  #   a => {nil => b},
  #   b => {nil => c},
  #   c => {Trailblazer::Activity::Right => d},
  #   # d => {Trailblazer::Activity::Right => create_success_terminus},
  # }

  # save_circuit = Circuit.new(map: save_circuit, termini: [Model___Output], start_task_id: a)

  # ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(save_circuit, {application_ctx: {params: {}, model: Object}})
  # ctx, signal = Pipeline::Processor.(save_pipe, {application_ctx: {params: {}, model: Object}})
  # raise ctx.inspect

    ## Benchmark circuit vs pipe.
    #
    # require "benchmark/ips"
    # Benchmark.ips do |x|
    #   x.report("circuit") { ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(save_circuit, {application_ctx: {params: {}, model: Object}}) }
    #   x.report("pipe")    { ctx, signal = Pipeline::Processor.(save_pipe, {application_ctx: {params: {}, model: Object}}) }

    #   x.compare!
    # end

# Learning:
##
# get rid of Pipeline. we can find a fast way to extend it at runtime.
#
# Warming up --------------------------------------
#              circuit     6.285k i/100ms
#                 pipe     7.877k i/100ms
# Calculating -------------------------------------
#              circuit     65.256k (± 2.8%) i/s -    326.820k in   5.012556s
#                 pipe     78.046k (± 1.3%) i/s -    393.850k in   5.047203s

# Comparison:
#                 pipe:    78046.2 i/s
#              circuit:    65255.8 i/s - 1.20x  (± 0.00) slower

  end

=begin
flow_options: :stack, :context_options

circuit_options: at specific points (activities) we want to make sure the steps/activities "beyond" receive certain variables.
  plus, they are immutable, all steps in one circuit receive the same set (ONLY USED FOR FUCKING exec_context and maybe one or two more)


arg = {
  ctx: {application_ctx: ..., }

  circuit_options: {exec_context: Create.new}
}


def call(ctx_for_task_invocation:, exec_context: )
  loop do
    task, invoker, circuit_options = next_for(  )

    invoker.(task, ctx.merge(circuit_options: circuit_options))
  end
end


[Create, MyInvoker, {exec_context: Create.new}] # Let Runner/Invoker add the exec_context.
  [:model, My___InstanceMethod___Step___Binary___Invoker, {}]


My___InstanceMethod___Step___Binary___Invoker(exec_context:)
  original_exec_context = exec_context


# invoker doesn't call Operation#call but grabs the @circuit

Create:
  circuit:
  exec_context:
  [invoker?]




Runner.(
  Create,
  circuit_options: {exec_context: Create.new, context_options: GLOBAL_CONTEXT_OPTIONS},
  invoker: Extract___Circuit___and___run___it, # FIXME: how to allow overriding #call?
  flow_options: {stack: []},
  application_ctx: {....},
  "before": "copy all variables",
  "after": "return original", # throw away all working variables.

    [
      {
        :model,

        "before": "{:exec_context ==> :filter_exec_context}, exec_context: InstanceMethod____Data___Behavior.new"
      }
    ]
)
=end
