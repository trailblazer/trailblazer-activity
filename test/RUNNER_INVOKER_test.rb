require "test_helper"



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
    def swap___(ctx, lib_ctx, signal, original_application_ctx:, aggregate:, **)
      # new_application_ctx = original_application_ctx.merge(aggregate) # DISCUSS: how to write on outer ctx?
      aggregate.each do |k, v|
        original_application_ctx[k] = v # FIXME: should we use Context#merge here? do we want a new ctx?

      end

      new_ctx = original_application_ctx

      return new_ctx, lib_ctx, signal
    end


    def create_application_ctx(ctx, lib_ctx, signal, aggregate:, **)
      new_ctx = Trailblazer::Context(aggregate)

      return new_ctx, lib_ctx, signal
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
        [
          :invoke_instance_method,
          :my_model_input,
          Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod,
          {exec_context: Create.new},
          Trailblazer::Activity::Circuit::Node::Processor::Scoped,
          {copy_to_outer_ctx: [:value]}
        ],
        [:add_value_to_aggregate, :add_value_to_aggregate],
      )

      more_model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:invoke_callable, Create::MoreModelInput, Trailblazer::Activity::Task::Invoker::StepInterface],
        [:add_value_to_aggregate, :add_value_to_aggregate],
      )

      my_model_output_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:invoke_instance_method, :my_model_output, Trailblazer::Activity::Task::Invoker::StepInterface::InstanceMethod, {exec_context: Create.new}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:value]}],
        [:add_value_to_aggregate, :add_value_to_aggregate],
      )

      # !!! requires: {exec_context: io}
      model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:save_original_application_ctx, :save_original_application_ctx],
        [:init_aggregate, :init_aggregate],
        [:my_model_input, my_model_input_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:aggregate]}],     # user filter.
        [:more_model_input, more_model_input_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:aggregate]}], # user filter.

        [:create_application_ctx, :create_application_ctx, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod],
      )

      # !!! requires: {exec_context: io}
      model_output_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
        [:init_aggregate, :init_aggregate],                          # DISCUSS: why do we need Scoped for my_model_output?
        [:my_model_output, my_model_output_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:aggregate]}],     # user filter.
        [:swap___, :swap___, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod],
      )


      model_instance_method_pipe = Trailblazer::Activity::Circuit::Builder::Step.InstanceMethod(:model)

      # model_instance_method_pipe = Trailblazer::Activity::Circuit::Adds.(model_instance_method_pipe,

      # [
      # :after]
      #   )
      # [:bla, ->(ctx, lib_ctx, signal, **) { raise signal.inspect }, Trailblazer::Activity::Task::Invoker::LibInterface, {}, Trailblazer::Activity::Circuit::Node::Processor, {}],


      model_tw_pipe = Trailblazer::Activity::Circuit::Builder.TaskWrap(
        [:input, model_input_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: io}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:original_application_ctx], return_outer_signal: true, copy_from_outer_ctx: []}], # change {:application_ctx}.
        [:"task_wrap.call_task", model_instance_method_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped],
        [:output, model_output_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: io}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {return_outer_signal: true, copy_from_outer_ctx: [:original_application_ctx]}],
      )

      # ctx = {params: {song: nil}, slug: "0x666"}


      run_checks_pipe      = Trailblazer::Activity::Circuit::Builder::Step.InstanceMethod(:run_checks)
      title_length_ok_pipe = Trailblazer::Activity::Circuit::Builder::Step.InstanceMethod(:title_length_ok?)

      success_pipe = pipeline_circuit([:success, success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), nil, {}, Trailblazer::Activity::Terminus])
      failure_pipe = pipeline_circuit([:failure, failure = Trailblazer::Activity::Terminus::Failure.new(semantic: :failure), nil, {}, Trailblazer::Activity::Terminus])

      validate_termini = {
        success: success, failure: failure
      }

      validate_circuit, ___validate_termini = Trailblazer::Activity::Circuit::Builder.Circuit(
        [:run_checks, run_checks_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_from_outer_ctx: [:exec_context]},
          {Trailblazer::Activity::Right => :title_length_ok?, Trailblazer::Activity::Left => :failure}
        ],
        [:title_length_ok?, title_length_ok_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_from_outer_ctx: [:exec_context]},
          {Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure}
        ],
        # FIXME: taskwrap for termini sucks.
        [:success, success_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor],
        [:failure, failure_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor],
        # [:failure, Trailblazer::Activity::Terminus::Failure.new(semantic: :failure), Trailblazer::Activity::Task::Invoker::CircuitInterface],

        termini: [:success, :failure]
      )

      # pp validate_circuit
      # raise
       # pp validate_termini
       # raise

      validate_tw_pipe = Trailblazer::Activity::Circuit::Builder.TaskWrap(
        [:"task_wrap.call_task", validate_circuit, Trailblazer::Activity::Circuit::Processor, {}],
      )
      # result = Trailblazer::Activity::Circuit::Processor.(
      #   validate_tw_pipe,
      #   ctx.merge(model: Object),
      #   {exec_context: io},
      #   nil,
      # )
      # raise result.inspect


      save_call_task_pipe = Trailblazer::Activity::Circuit::Builder::Step.Callable(Save)

      save_tw_pipe = Trailblazer::Activity::Circuit::Builder.TaskWrap(
        [:"task_wrap.call_task", save_call_task_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped,],
      )

      create_circuit, create_termini = Trailblazer::Activity::Circuit::Builder.Circuit(
        # [:bla, ->(ctx, lib_ctx, signal, **) { raise lib_ctx.inspect }, Trailblazer::Activity::Task::Invoker::LibInterface, {}, Trailblazer::Activity::Circuit::Node::Processor, {}],
        [:"model.task_wrap", model_tw_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: Create.new.freeze}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_from_outer_ctx: []},
          {Trailblazer::Activity::Right => :"validate.task_wrap", Trailblazer::Activity::Left => :failure}
        ], # TODO: circuit_options should be set outside of Create, in the canonical invoke.
        [:"validate.task_wrap", validate_tw_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: Validate.new.freeze}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {},
          {validate_termini[:success] => :"save.task_wrap", validate_termini[:failure] => :failure}
        ],
        [:"save.task_wrap", save_tw_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {},
          {Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure}
        ], # check that we don't have circuit_options anymore here?
        [:success, Trailblazer::Activity::Terminus::Success.new(semantic: :success), nil, {}, Trailblazer::Activity::Terminus],
        [:failure, Trailblazer::Activity::Terminus::Failure.new(semantic: :failure), nil, {}, Trailblazer::Activity::Terminus],

        termini: [:success, :failure]
      )

      return create_circuit, create_termini, model_input_pipe, model_output_pipe, validate_termini, save_tw_pipe
    end
  end

  it "wrap_runtime prototyping" do
    create_circuit, create_termini, _, _, validate_termini, save_tw_pipe = Fixtures.fixtures

    ctx = {params: {song: nil}, slug: 666}

    class MyTrace
      def self.capture_before(ctx, lib_ctx, signal, stack:, task:, **) # FIXME: we need circuit_options for the {:task}.
        # task = circuit_options[:task] or raise
        # stack << [:before, task, ctx.to_h.inspect]
        stack += [[:before, task, ctx.to_h.inspect]] # treat stack as an immutable object
# puts "         ~~~ trace in #{task.inspect}: #{stack}"

        return ctx, lib_ctx.merge(stack: stack), signal
      end

      def self.capture_after(ctx, lib_ctx, signal, stack:, task:, **) # FIXME: we need circuit_options for the {:task}.
        # puts "     @@@@@ #{stack.inspect}"
        # stack << [:after, task, ctx.to_h.inspect, signal]
        stack += [[:after, task, ctx.to_h.inspect, signal]]

        # puts "@@@@@ CA, #{task} #{signal.inspect}"

        return ctx, lib_ctx.merge(stack: stack), signal
      end
    end

    # Since a Processor is only called for Circuit instances, we can simply
    # extend the circuit at runtime.
    # class WrapRuntime < Struct.new(:original_invoker)
    class WrapRuntime #< Trailblazer::Activity::Circuit::Processor
      # Extension for a particular node in Processor#call.
      class Extension < Struct.new(:adds_instructions) # "taskWrap" extension.
        def call(id, task_circuit, invoker, *args)
          # puts "~~~ @@@@@ #{id.inspect} #{args}"/
          # NOTE: here, we create an extended circuit for the "task".
          task_circuit = Trailblazer::Activity::Circuit::Adds.(task_circuit, *adds_instructions)

          return id, task_circuit, invoker, *args
        end
      end
    end

    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tw_extension = WrapRuntime::Extension.new(
      [
        [[:capture_before, :capture_before, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {exec_context: MyTrace},
          Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:stack]}], :before],
        [[:capture_after, :capture_after, Trailblazer::Activity::Task::Invoker::LibInterface::InstanceMethod, {exec_context: MyTrace},
          Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:stack]}], :after],
      ]
    )

    tw_create_pipe = Fixtures.pipeline_circuit(
      [:"tw.call_task", create_circuit, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {}]
    )

    canonical_pipe = Fixtures.pipeline_circuit( # DISCUSS: we could directly use {Processor.invoke_task} here?
      [:Create, tw_create_pipe, Trailblazer::Activity::Circuit::Processor, {}, _A::Circuit::Node::Processor::Scoped]
    )

    # in wtf?, we have to replacce the outer Processor as we WANT the {:wrap_runtime} feature.
    # this is cool since it's normally not applied, which is hopefully faster.
    # my_wrap_runtime_processor = Class.new(Trailblazer::Activity::Circuit::Processor) do
    #   extend WrapRuntime::InvokeTask # FIXME: super slow!
    # end

    my_wrap_runtime_runner = Class.new(_A::Circuit::Node::Runner) do
      def self.call(node, ctx, lib_ctx, signal, wrap_runtime:, **circuit_options)
        # raise lib_ctx[:task].inspect
        id, task, interface, lib_options_to_merge, scope, scope_options = node
        puts "@@@@@____ #{id.inspect} #{task.class}"

        raise "no scope_options set in #{id}" if scope_options.nil?

        in_ = scope_options[:copy_from_outer_ctx]
        out_ = scope_options[:copy_to_outer_ctx] || []

        # using :copy_from_outer_ctx is whitelisting (once you use it), and [] means "don't pass anything in"
        if in_.is_a?(Array)
          in_ += [:stack]
          scope_options = scope_options.merge(copy_from_outer_ctx: in_)
        end


        if task.is_a?(Trailblazer::Activity::Circuit)
          if scope == Trailblazer::Activity::Circuit::Node::Processor
            scope = Trailblazer::Activity::Circuit::Node::Processor::Scoped
            # raise id.inspect
            # problem is, a non-Scoped simply drops everything from the inside. However, we need :stack, so we need to change the Node::Processor here.
          end
puts "+++++++++=extending #{id}"
          new_out = out_ + [:stack]
          scope_options = scope_options.merge(copy_to_outer_ctx: new_out)

          node = [id, task, interface, lib_options_to_merge, scope, scope_options]
        end

  # puts "@@@@@ #{id.inspect}"
              # puts "i will wrap #{id.inspect}"
        if task.instance_of?(Trailblazer::Activity::Circuit::Pipeline)
          node = extend_task_wrap_pipeline(wrap_runtime, id, node)
        end

        super#(node, ctx, lib_ctx, signal, wrap_runtime: wrap_runtime, **circuit_options)
      end

      def self.extend_task_wrap_pipeline(wrap_runtime, id, node)
        tw_extension = wrap_runtime[id] # FIXME: this should be looked up by path, not ID.

        id, extended_task, invoker, lib_options_to_merge, processor, options = tw_extension.(*node.to_a) # DISCUSS: pass runtime options here, too?

        lib_options = lib_options_to_merge.merge(task: id)


        pp extended_task.map.keys
        # puts "@@@@@? #{extended_task.config[:capture_before][3].inspect}"

        _node = [id, extended_task, invoker, lib_options, processor, options]
      end
    end

# DEBUGGING

# call save's taskWrap:
save_call_task_node = save_tw_pipe.config[:"task_wrap.call_task"]

    ctx, lib_ctx, signal = my_wrap_runtime_runner.(
      save_call_task_node,
      {model: Object},
      {
        stack: [].freeze,
      },
      nil,
      runner: my_wrap_runtime_runner,
      wrap_runtime: Hash.new(my_tw_extension),
    )

    assert_equal lib_ctx[:stack],
      [[:before, :"task_wrap.call_task", "{:model=>Object}"], [:after, :"task_wrap.call_task", "{:model=>Object, :save=>Object}", Trailblazer::Activity::Right]]

# call Model's taskWrap:
    model_tw_node = create_circuit.config[:"model.task_wrap"]

    ctx, lib_ctx, signal = my_wrap_runtime_runner.(
      model_tw_node,
      {params: {}, slug: "0x999"},
      {
        stack: [].freeze,
      },
      nil,
      runner: my_wrap_runtime_runner,
      wrap_runtime: Hash.new(my_tw_extension),
    )


    assert_equal lib_ctx[:stack][8], [:after, :"task_wrap.call_task", "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", Trailblazer::Activity::Right]

    assert_equal lib_ctx[:stack], [
      [:before, :"model.task_wrap", "{:params=>{}, :slug=>\"0x999\"}"],
      [:before, :input, "{:params=>{}, :slug=>\"0x999\"}"],
      [:before, :my_model_input, "{:params=>{}, :slug=>\"0x999\"}"],
      [:after, :my_model_input, "{:params=>{}, :slug=>\"0x999\"}", nil],
      [:before, :more_model_input, "{:params=>{}, :slug=>\"0x999\"}"],
      [:after, :more_model_input, "{:params=>{}, :slug=>\"0x999\"}", nil],
      [:after, :input, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\"}", nil],
      [:before, :"task_wrap.call_task", "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\"}"],
      [:after, :"task_wrap.call_task", "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", Trailblazer::Activity::Right],
      [:before, :output, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}"],
      [:before, :my_model_output, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}"],
      [:after, :my_model_output, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", nil],
      [:after, :output, "{:params=>{}, :slug=>\"0x999\", :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", nil],
      [:after, :"model.task_wrap", "{:params=>{}, :slug=>\"0x999\", :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", Trailblazer::Activity::Right]
    ]


# raise "wooohoo"
tw_create_pipe = Trailblazer::Activity::Circuit::Builder.TaskWrap(
      [:"task_wrap.call_task", create_circuit, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped]
    )

    canonical_node = [:Create, tw_create_pipe, Trailblazer::Activity::Circuit::Processor, {}, _A::Circuit::Node::Processor::Scoped, {}]
puts "yo"
    ctx = {params: {song: nil}, slug: 666}

    # validation error:
    ctx, lib_ctx, signal = my_wrap_runtime_runner.( # we don't need another circuit around the OP tw, do we?
      canonical_node,
      ctx,
      {
        stack: [].freeze,
      },
      nil,
      runner: my_wrap_runtime_runner,
      wrap_runtime: Hash.new(my_tw_extension),
    )

    assert_equal ctx, {:params=>{:song=>nil}, slug: 666, :model=>"Object  / {:more=>666}", :errors=>["Object  / {:more=>666}", :song]}
    assert_equal lib_ctx.keys, [:stack]
    assert_equal signal, create_termini[:failure]

    pp lib_ctx[:stack]

    assert_equal lib_ctx[:stack], [
      [:before, :Create, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :"model.task_wrap", "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :my_model_input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :my_model_input, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :more_model_input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :more_model_input, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:after, :input, "{:params=>{:song=>nil, :slug=>666}, :more=>666}", nil],
      [:before, :"task_wrap.call_task", "{:params=>{:song=>nil, :slug=>666}, :more=>666}"],
      [:after, :"task_wrap.call_task", "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],

       [:before, :output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
       [:before, :my_model_output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
       [:after, :my_model_output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", nil],
       [:after, :output, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}", nil],
       [:after, :"model.task_wrap", "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],
       [:before, :"validate.task_wrap", "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}"],
        [:before, :run_checks, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}"],
        [:after, :run_checks, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", Trailblazer::Activity::Left],
        [:before, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}"],
        [:after, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_termini[:failure]],
        [:after, :"validate.task_wrap", "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_termini[:failure]],
        [:after, :Create, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", create_termini[:failure]]
    ]

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

  require "ruby-prof"
  it "ruby-prof" do
    create_circuit, create_termini, model_input_pipe, model_output_pipe = Fixtures.fixtures()
    # profile the code
    result = RubyProf::Profile.profile do
      puts call_me(create_circuit)
    end

    # print a graph profile to text
    printer = RubyProf::FlatPrinter.new(result)
    printer.print(STDOUT)
  end


require "benchmark/ips"
  it do
    create_circuit, create_termini, model_input_pipe, model_output_pipe = Fixtures.fixtures()

    # context_implementation = Trailblazer::Context
    context_implementation = Trailblazer::MyContext
    context_implementation = Trailblazer::MyContext_No_Slice

# TEST I/O

#  Benchmark.ips do |x|
#    x.report("cix") {
  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(model_input_pipe,
    {params: {song: {}}, noise: true, slug: "0x666"},
    {exec_context:  IO___.new},
    nil,
    # copy_to_outer_ctx: [:original_application_ctx],
    runner:  _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
  )

  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Node::Runner.(
    [:my_model, model_input_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {copy_to_outer_ctx: [:original_application_ctx]}],
    {params: {song: {}}, noise: true, slug: "0x666"},
    {exec_context:  IO___.new},
    nil,
    runner:  _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
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
  assert_equal lib_ctx.keys, [:exec_context, :original_application_ctx]
  assert_equal CU.inspect(ctx), %(#<struct Trailblazer::Context shadowed={:params=>{:song=>{}, :slug=>\"0x666\"}, :more=>\"0x666\"}, mutable={}>)

  # this is what happens in the actual {:model} step.
  ctx[:model] = Object

  # ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(model_output_pipe,
  #   ctx,
  #   lib_ctx,
  #   {copy_to_outer_ctx: [],
  #       exec_context: IO___.new,},
  #   nil
  # )
  ctx = ctx.to_h
  puts :yoo

  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Node::Runner.(
    [:my_model, model_output_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Processor::Scoped, {}],
    ctx,
    lib_ctx,
    nil,
    runner:  _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
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
  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, ctx, {}, nil, runner: _A::Circuit::Node::Runner, context_implementation: context_implementation,) # FIXME: use process_node/canonical invoke?

  assert_equal ctx, {:params=>{:song=>nil}, slug: "0x666", :model=>"Object  / {:more=>\"0x666\"}", :errors=>["Object  / {:more=>\"0x666\"}", :song]}
  assert_equal lib_ctx.keys, []
  assert_equal signal, create_termini[:failure]

puts "ywiiii"
  # success:
  ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"}, {}.freeze, nil,
    runner: _A::Circuit::Node::Runner,
    context_implementation: context_implementation,
  )

  assert_equal ctx, {:params=>{:song=>{title: "Uwe"}, id: 1}, slug: "0x666", :model=>"Object 1 / {:more=>\"0x666\"}", :save=>"Object 1 / {:more=>\"0x666\"}"}
  assert_equal lib_ctx.keys, []
  assert_equal signal, create_termini[:success]

end

  it "run benchmark" do
    create_circuit, = Fixtures.fixtures()

    Benchmark.ips do |x|
      x.report("simple hash Context") {
        ctx, signal = call_me_with_simpler_context(create_circuit)
      }
      x.compare!
    end
  end

  it "run benchmark for different {:context_implementation}" do
    create_circuit, = Fixtures.fixtures()

    Benchmark.ips do |x|
      x.report("cix") {
        ctx, signal = call_me(create_circuit)
      }
      x.report("hash Contextt") {
        ctx, signal = call_me_with_simpler_context(create_circuit)
      }
      x.report("hash Contextt no slice") {
        ctx, signal = call_me_with_simpler_context_and_no_slice(create_circuit)
      }
      x.compare!
    end
  end

  def call_me(create_circuit)
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"} , {}, nil,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::Context,
    )
  end

  def call_me_with_simpler_context(create_circuit)
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"} , {}, nil,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext,
    )
  end

  def call_me_with_simpler_context_and_no_slice(create_circuit)
    ctx, lib_ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"} , {}, nil,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::MyContext_No_Slice,
    )
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
