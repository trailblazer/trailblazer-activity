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
        # puts variables.keys
        Context.new(shadowed, mutable.merge(variables))
      end

      def decompose
        return shadowed, mutable
      end

      def to_h
        # return @to_h
        shadowed.to_h.merge(mutable)
      end

      def to_hash # implicit conversion to Hash.
        to_h
      end
    end

    def self.Context(shadowed)
      Context.new(shadowed, {})
    end
  end

# TODO:
# 1. SOMETHINg like Pipe::Input, nested pipe, check out how to use a work ctx
# 2. do we need pipelines?
# 3. runtime tw
# 4. show how task can be replaced at runtime, e.g. for Nested
# 5. how to call with kwargs, e.g. in Rescue?
# 6. "scopes" for tracing? E.g. "only trace business steps"
# 7. try saving memory by providing often-used Pipes, e.g. for IO?
# 8. how would we change the "circuit options" from a step? ===> change :start_task
# 9. does invoker.call need kwargs?
# 10. BUG: when all tasks are the same proc and the last is the terminus, only the first is run. ===> use ids, we got them, anyway.
# 11. should circuit_options be a positional arg?
# 12. don't repeat Io.new as context, use automatic passing [done]
# 13. termini IDs in map when using nesting

class RunnerInvokerTest < Minitest::Spec
  # Helper for those who don't like or have a DSL :D
  def pipeline_circuit(*task_cfgs)
    task_cfgs = task_cfgs.collect do |id, task, invoker = Trailblazer::Activity::Task::Invoker::CircuitInterface, options = {}, signal: nil|
      [
        id, task, invoker, options, signal # FIXME: we don't need the signal at runtime.
      ]
    end

    map = task_cfgs.collect.with_index do |(id, _, _, _, signal), i|
      next_task = task_cfgs[i + 1]

      [
        id,
        {signal => next_task ? next_task[0] : nil} # FIXME: don't link last task at all!
      ]

    end.to_h

    config = task_cfgs.collect do |(id, *args)|
      [id, [id, *args]]
    end.to_h

    Trailblazer::Activity::Circuit.new(
      map:        map,
      start_task: config.keys[0],
      termini:    [config.keys[-1]],
      config:     config,
    )
  end







  class INVOKER___STEP_INTERFACE
    # def self.call(task, ctx, application_ctx:, **)
    def self.call(task, ctx, **)
       application_ctx = ctx[:application_ctx]

      result = task.(application_ctx, **application_ctx.to_h)
      # pp application_ctx

      ctx[:value] = result

      return ctx, nil # DISCUSS: value. FIXME: redundant to INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT
    end
  end

  class INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT
    # def self.call(task, ctx, exec_context:, application_ctx:, use_application_ctx___: true, **)
    def self.call(task, ctx, exec_context:, use_application_ctx___: true, **)
       application_ctx = ctx[:application_ctx]

      target_ctx = use_application_ctx___ ? application_ctx : ctx # FIXME: not happy with this AT ALL.
# puts " invok @@@@@ #{task.inspect}"
      result = exec_context.send(task, target_ctx, **target_ctx.to_h)

      ctx[:value] = result
      return ctx, nil # DISCUSS: value
    end
  end

  it "circuit_options, depth-only" do
    def capture_task(id:)
      ->(ctx, exec_context:, lib_exec_context: nil, **) { ctx[:captured] << [id, exec_context, lib_exec_context].compact; return ctx, nil }
    end

    model_pipe = pipeline_circuit(
      [:input, capture_task(id: 1)],
      [:model, capture_task(id: 2)],
      [:output, capture_task(id: 3)],
    )

    validate_input_pipe = pipeline_circuit(
      [:input, capture_task(id: 4)],
      [:exec_on__parent, capture_task(id: 5)], # exec on original ctx!

    )

    validate_pipe = pipeline_circuit(
      [:Validate_input, validate_input_pipe, Trailblazer::Activity::Circuit::Processor, {lib_exec_context: "Validate::Input"}],
      [:validate, capture_task(id: 6)],
    )

    create_pipe = pipeline_circuit(
      [:Model, model_pipe, Trailblazer::Activity::Circuit::Processor],
      [:Validate, validate_pipe, Trailblazer::Activity::Circuit::Processor],
    )

    # As we pass in exec_context: as a kwarg, it's passed to all siblings etc.
    ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_pipe, {captured: [], exec_context: "Object"})
    assert_equal ctx[:captured], [[1, "Object"], [2, "Object"], [3, "Object"], [4, "Object", "Validate::Input"], [5, "Object", "Validate::Input"], [6, "Object"]]

# FIXME: new test case.
puts
    create_pipe = pipeline_circuit(
      [:Model, model_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: "Model"}],
      [:Validate, validate_pipe, Trailblazer::Activity::Circuit::Processor],
    )

    ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_pipe, {captured: [], exec_context: "Object"})
    assert_equal ctx[:captured], [[1, "Model"], [2, "Model"], [3, "Model"], [4, "Object", "Validate::Input"], [5, "Object", "Validate::Input"], [6, "Object"]]

  end

it do
  class ComputeBinarySignal
    def self.call(ctx, value:, **)
      signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

      ctx[:signal] = signal

      return ctx, nil
    end
  end

  class Create
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
      def self.call(ctx, slug:, **)
        {
          more: slug
        }
      end
    end

    # Out() => [:model]
    def my_model_output(ctx, model:, **)
      {
        model: model
      }
    end
  end

  class Validate
    def run_checks(ctx, params:, model:, **)
      if params[:song]
        return true
      else
        ctx[:errors] = [model, :song]
        return false
      end
    end

    def title_length_ok?(ctx, params:, **)
      return false unless params[:song][:title]

      return true
    end
  end

  # step interface.
  class Save
    def self.call(ctx, model:, **)
      ctx[:save] = model
    end
  end

  class IO___
    def init_aggregate(ctx, **)
      ctx[:aggregate] = {}

      return ctx, nil
    end

    # def add_value_to_aggregate(ctx, aggregate:, value:, **)
    def add_value_to_aggregate(ctx, value:, aggregate:, **)
      ctx[:aggregate] = aggregate.merge(value)

      return ctx, nil
    end

    def save_original_application_ctx(ctx, application_ctx:, **)
      ctx[:original_application_ctx] = application_ctx # the "outer ctx".

      return ctx, nil
    end

    def swap___(ctx, application_ctx:, original_application_ctx:, aggregate:, **)
      # new_application_ctx = original_application_ctx.merge(aggregate) # DISCUSS: how to write on outer ctx?
      aggregate.each do |k, v|
        original_application_ctx[k] = v # FIXME: should we use Context#merge here? do we want a new ctx?

      end

      ctx[:application_ctx] = original_application_ctx

      return ctx, nil
    end


    def create_application_ctx(ctx, aggregate:, **)
      ctx[:application_ctx] = Trailblazer::Context(aggregate) # DISCUSS: write to {ctx} or use merge?

      return ctx, nil
    end
  end
  Io = IO___.new

  # In() => :my_model_input
  my_model_input_pipe = pipeline_circuit(
    [:invoke_instance_method, :my_model_input, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT, {exec_context: Create.new}],
    [:add_value_to_aggregate, :add_value_to_aggregate, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {use_application_ctx___: false}],
  )

  more_model_input_pipe = pipeline_circuit(
    [:invoke_callable, Create::MoreModelInput, INVOKER___STEP_INTERFACE],
    [:add_value_to_aggregate, :add_value_to_aggregate, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {use_application_ctx___: false}],
  )

  my_model_output_pipe = pipeline_circuit(
    [:invoke_instance_method, :my_model_output, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT, {exec_context: Create.new}],
    [:add_value_to_aggregate, :add_value_to_aggregate, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {exec_context: Io, use_application_ctx___: false}],
  )
# raise "the original_application_ctx must be available to output, but not to the next real step"

  # !!! requires: {exec_context: Io}
  model_input_pipe = pipeline_circuit(
    [:save_original_application_ctx, :save_original_application_ctx, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
    [:init_aggregate, :init_aggregate, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
    [:my_model_input, my_model_input_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:aggregate]}],     # user filter.
    [:more_model_input, more_model_input_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:aggregate]}], # user filter.
    [:create_application_ctx, :create_application_ctx, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
  )

  # !!! requires: {exec_context: Io}
  model_output_pipe = pipeline_circuit(
    [:init_aggregate, :init_aggregate, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
    [:my_model_output, my_model_output_pipe, Trailblazer::Activity::Circuit::Processor],     # user filter.
    [:swap___, :swap___, Trailblazer::Activity::Task::Invoker::CircuitInterface::InstanceMethod, {}],
  )



# raise "should we merge ctx and temp_ctx in Processor, or do that in the invoker?
#{ } how to handle signal?"

  model_pipe = pipeline_circuit(
    [:input, model_input_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {exec_context: Io, copy_to_outer_ctx: [:application_ctx, :original_application_ctx].freeze}], # change {:application_ctx}.

    [:invoke_instance_method, :model, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT, {exec_context: Create.new}],
    [:compute_binary_signal, ComputeBinarySignal],
    [:output, model_output_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {exec_context: Io, copy_to_outer_ctx: [:application_ctx].freeze}],
  )

  run_checks_pipe = pipeline_circuit(
    [:invoke_instance_method, :run_checks, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT], # FIXME: we're currenly assuming that exec_context is passed down.
    [:compute_binary_signal, ComputeBinarySignal],
  )

  title_length_ok_pipe = pipeline_circuit(
    [:invoke_instance_method, :title_length_ok?, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT],
    [:compute_binary_signal, ComputeBinarySignal],
  )

  validate_config = {
    run_checks: [:run_checks, run_checks_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:application_ctx], emit_signal: true}],
    title_length_ok?: [:title_length_ok?, title_length_ok_pipe, Trailblazer::Activity::Circuit::Processor::Scoped, {copy_to_outer_ctx: [:application_ctx], emit_signal: true}],
    validate_success_terminus: [:validate_success_terminus, Trailblazer::Activity::Terminus::Success.new(semantic: :success), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],
    validate_failure_terminus: [:validate_failure_terminus, Trailblazer::Activity::Terminus::Failure.new(semantic: :failure), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],
  }

  validate_circuit = {
    :run_checks => {Trailblazer::Activity::Right => :title_length_ok?, Trailblazer::Activity::Left => :validate_failure_terminus},
    :title_length_ok? => {Trailblazer::Activity::Right => :validate_success_terminus, Trailblazer::Activity::Left => :validate_failure_terminus},
    # FIXME_SUCCESS => {},
    # FIXME_FAILURE => {},
  }
  validate_circuit = Trailblazer::Activity::Circuit.new(map: validate_circuit, termini: [:validate_success_terminus, :validate_failure_terminus], start_task: :run_checks, config: validate_config)

  save_pipe = pipeline_circuit(
    [:invoke_callable, Save, INVOKER___STEP_INTERFACE],
    [:compute_binary_signal, ComputeBinarySignal],
  )

  create_config = {
    Model:    [:Model,    model_pipe, Trailblazer::Activity::Circuit::Processor::Scoped,      {exec_context: Create.new.freeze, copy_to_outer_ctx: [:application_ctx], emit_signal: true},], # TODO: circuit_options should be set outside of Create, in the canonical invoke.
    Validate: [:Validate, validate_circuit, Trailblazer::Activity::Circuit::Processor::Scoped, {exec_context: Validate.new.freeze, copy_to_outer_ctx: [:application_ctx]},], # TODO: always emit :application_ctx?
    Save:     [:Save,     save_pipe, Trailblazer::Activity::Circuit::Processor::Scoped,       {copy_to_outer_ctx: [:application_ctx], emit_signal: true}], # check that we don't have circuit_options anymore here?
    create_success_terminus: [:create_success_terminus, Trailblazer::Activity::Terminus::Success.new(semantic: :success), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],
    create_failure_terminus: [:create_failure_terminus, Trailblazer::Activity::Terminus::Failure.new(semantic: :failure), Trailblazer::Activity::Task::Invoker::CircuitInterface, {}]
  }




  create_circuit = {
    :Model => {Trailblazer::Activity::Right => :Validate, Trailblazer::Activity::Left => :create_failure_terminus}, # DISCUSS: reuse termini?
    :Validate => {validate_config[:validate_success_terminus][1] => :Save, validate_config[:validate_failure_terminus][1] => :create_failure_terminus},
    :Save => {Trailblazer::Activity::Right => :create_success_terminus, Trailblazer::Activity::Left => :create_failure_terminus},
  }

  create_circuit = Trailblazer::Activity::Circuit.new(map: create_circuit, termini: [:create_success_terminus, :create_failure_terminus], start_task: :Model, config: create_config)



# TEST I/O
require "benchmark/ips"
#  Benchmark.ips do |x|
#    x.report("cix") {
  ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(model_input_pipe,
    {
      application_ctx: {params: {song: {}}, noise: true, slug: "0x666"},
    },
    # {}, # tmp
    # exec_context: create_instance = Create.new,
    exec_context:  Io,
    scope: true,
    copy_to_outer_ctx: [:application_ctx, :original_application_ctx].freeze
  )
 # }
 #   x.compare! # 43.6 -45.2k
 # end

   # Context():
   #   1.) 25.4k
   #   2.) 36.7k (simple Context)

  # raise ctx.inspect
  assert_equal ctx[:application_ctx].class, Trailblazer::Context # our In pipe's creation!
  assert_equal ctx[:application_ctx][:more], "0x666" # the more_model_input was called.
  assert_equal ctx[:original_application_ctx].class, Hash # the OG ctx is a Hash.
  assert_equal ctx.keys, [:application_ctx, :original_application_ctx]
  assert_equal CU.inspect(ctx), %({:application_ctx=>#<struct Trailblazer::Context shadowed={:params=>{:song=>{}, :slug=>\"0x666\"}, :more=>\"0x666\"}, mutable={}>, :original_application_ctx=>{:params=>{:song=>{}}, :noise=>true, :slug=>\"0x666\"}})

  # this is what happens in the actual {:model} step.
  ctx[:application_ctx][:model] = Object

  ctx, signal = Trailblazer::Activity::Circuit::Processor::Scoped.(model_output_pipe, ctx,
    scope: true,
    copy_to_outer_ctx: [:application_ctx],
    exec_context: Io,
  )

# FIXME!!!!!!!!!!!!!!!!!!!!!! original_application_ctx shooouldn't contain {model}?
  assert_equal ctx.inspect, %({:application_ctx=>{:params=>{:song=>{}}, :noise=>true, :slug=>"0x666", :model=>Object}, :original_application_ctx=>{:params=>{:song=>{}}, :noise=>true, :slug=>"0x666", :model=>Object}})















  ctx = {params: {song: nil}, slug: "0x666"}
  create_ctx = {
    # exec_context:     Create.new,
    application_ctx:  ctx
  }

puts "ciiii"
  # validation error:
  ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, create_ctx)

  assert_equal ctx[:application_ctx], {:params=>{:song=>nil}, slug: "0x666", :model=>"Object  / {:more=>\"0x666\"}", :errors=>["Object  / {:more=>\"0x666\"}", :song]}
  assert_equal ctx.keys, [:application_ctx]
  assert_equal signal, create_config[:create_failure_terminus][1]

  # success:
  ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, {application_ctx: _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"}})

  assert_equal ctx[:application_ctx], {:params=>{:song=>{title: "Uwe"}, id: 1}, slug: "0x666", :model=>"Object 1 / {:more=>\"0x666\"}", :save=>"Object 1 / {:more=>\"0x666\"}"}
  assert_equal signal, create_config[:create_success_terminus][1]
  assert_equal ctx.keys, [:application_ctx]

  def call_me(create_circuit)
    ctx, signal = Trailblazer::Activity::Circuit::Processor.(create_circuit, {application_ctx: _ctx = {params: {song: {title: "Uwe"}, id: 1}, slug: "0x666"}})

  end

  Benchmark.ips do |x|
    x.report("cix") {
      ctx, signal = call_me(create_circuit)
    }
    x.compare!
  end

  # 1.
  #   5.648k vs 19.834k how is that so slow?
  # 2. circuit map now is based on ID symbols and not [id, task, invoker, ...] which was obviously very slow to compute the key every time
  #   21.847k that is a lot faster!

  # save_pipe = [
  #   a = [:input, Model___Input, Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],

  #   b= [:invoke_callable, Save, INVOKER___STEP_INTERFACE, {}],
  #   c= [:compute_binary_signal, ComputeBinarySignal, Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],

  #   d =[:output, Model___Output, Trailblazer::Activity::Task::Invoker::CircuitInterface, {}],
  # ]


  # save_circuit = {
  #   a => {nil => b},
  #   b => {nil => c},
  #   c => {Trailblazer::Activity::Right => d},
  #   # d => {Trailblazer::Activity::Right => create_success_terminus},
  # }

  # save_circuit = Circuit.new(map: save_circuit, termini: [Model___Output], start_task: a)

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

  class INVOKER___CIRCUIT_INTERFACE___INSTANCE_METHOD_ON_EXEC_CONTEXT # GREAT thing here, we can use it for businesss and for library tasks.
    def self.call(ctx, flow_options, circuit_options, task:, **kwargs)
      exec_context = circuit_options.fetch(:exec_context) # PROBLEM HERE, business exec_context or lib exec_context?

      exec_context.send(task, ctx, flow_options, circuit_options, **kwargs)
    end
  end
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
