require "test_helper"

# TODO:
# 1. SOMETHINg like Pipe::Input, nested pipe, check out how to use a work ctx
# 2. do we need pipelines?
# 3. runtime tw
# 4. show how task can be replaced at runtime, e.g. for Nested
# 5. how to call with kwargs, e.g. in Rescue?

class RunnerInvokerTest < Minitest::Spec
it do
  # We start with NO #call methods!
  class Circuit < Struct.new(:map, :start_task, :termini, keyword_init: true)
    class Processor
      def self.call(circuit, ctx, **)
        map      = circuit.map
        termini  = circuit.termini
        task_cfg = circuit.start_task

        loop do
          id, task, invoker, circuit_options_to_merge = task_cfg

          puts "@@@@@ circuit [invoke] #{id.inspect}"
          ctx = ctx.merge(circuit_options_to_merge)

          ctx, signal = invoker.( # TODO: redundant with {Pipeline::Processor.call}.
            task,
            ctx,
            **ctx,
          )

          # Stop execution of the circuit when we hit a terminus.
          # puts "@@@@@ #{termini.collect { |o| o} } ??? #{signal.object_id} #{signal}"
          if termini.include?(task)
            # puts "done with circuit #{task}"
            return ctx, signal
          end

          if next_task_cfg = next_for(map, task_cfg, signal)
            task_cfg = next_task_cfg
            # puts "@@@@@ =========> #{next_task_cfg.inspect}"
          else
            raise signal.inspect
            # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
          end
        end
      end

      def self.next_for(map, last_task_cfg, signal)
        outputs = map[last_task_cfg]
        outputs[signal]
      end
    end

    module Terminus
      class Success < Struct.new(:semantic, keyword_init: true)
        def call(ctx, **)
          return ctx, self
        end
      end

      class Failure < Success
      end
    end
  end

  class INVOKER___CIRCUIT_INTERFACE_ON_EXEC_CONTEXT
    def self.call(task, ctx, exec_context:, kwargs: {}, **)
      exec_context.send(task, ctx, **ctx.to_h) # TODO: how to add kwargs for Rescue.
    end
  end

  class INVOKER___CIRCUIT_INTERFACE
    def self.call(task, ctx, **)
      task.(ctx, **ctx.to_h)
    end
  end

  class INVOKER___STEP_INTERFACE
    def self.call(task, ctx, application_ctx:, **)
      result = task.(application_ctx, **application_ctx.to_h)
      # pp application_ctx

      return ctx.merge(value: result,
        # application_ctx: application_ctx
        ), nil # DISCUSS: value. FIXME: redundant to INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT
    end
  end

  class INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT
    def self.call(task, ctx, exec_context:, application_ctx:, **)

      result = exec_context.send(task, application_ctx, **application_ctx.to_h)

      return ctx.merge(value: result), nil # DISCUSS: value
    end
  end

  # Helper for those who don't like or have a DSL :D
  def pipeline_circuit(*task_cfgs)
    task_cfgs = task_cfgs.collect do |id, task, invoker = INVOKER___CIRCUIT_INTERFACE, options = {}, signal: nil|
      [
        id, task, invoker, options, signal # FIXME: we don't need the signal at runtime.
      ]
    end

    circuit = task_cfgs.collect.with_index do |task_cfg, i|
      signal = task_cfg[-1]

      [
        task_cfg,
        {signal => task_cfgs[i + 1]} # FIXME: don't link last task!
      ]

    end.to_h

    Circuit.new(
      map:        circuit,
      start_task: task_cfgs[0],
      termini:    [task_cfgs[-1][1]]
    )
  end

  class ComputeBinarySignal
    def self.call(ctx, value:, **)
      signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

      ctx[:signal] = signal

      return ctx, nil
    end
  end

  class Model___Input
    def self.call(ctx, **)
      ctx = Trailblazer::Context(ctx)

      return ctx, nil
    end
  end

  class Model___Output
    def self.call(ctx, signal:, **)
      ctx, _ = ctx.decompose
      return ctx, signal # FIXME: how do we return the computed "real" signal?
    end
  end

  class Create
    def model(ctx, params:, **)
      ctx[:model] = "Object #{params[:id]}"
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

  # model_pipe = [
  #   [:input, Model___Input, INVOKER___CIRCUIT_INTERFACE],

  #   [:invoke_instance_method, :model, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT, {task: :model}],
  #   [:compute_binary_signal, ComputeBinarySignal, INVOKER___CIRCUIT_INTERFACE],

  #   [:output, Model___Output, INVOKER___CIRCUIT_INTERFACE],
  # ]
  model_pipe = pipeline_circuit(
    [:input, Model___Input],                                                      # DISCUSS: can we somehow save these steps?
    [:invoke_instance_method, :model, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT],
    [:compute_binary_signal, ComputeBinarySignal],
    [:output, Model___Output],                                                    # DISCUSS: can we somehow save these steps?
  )
  # pp model_pipe

  run_checks_pipe = pipeline_circuit(
    [:input, Model___Input],
    [:invoke_instance_method, :run_checks, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT],
    [:compute_binary_signal, ComputeBinarySignal],
    [:output, Model___Output],
  )

  title_length_ok_pipe = pipeline_circuit(
    [:input, Model___Input],
    [:invoke_instance_method, :title_length_ok?, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT],
    [:compute_binary_signal, ComputeBinarySignal],
    [:output, Model___Output],
  )

  run_checks      = [:run_checks, run_checks_pipe, Circuit::Processor, {}]
  title_length_ok = [:title_length_ok?, title_length_ok_pipe, Circuit::Processor, {}]
  validate_success_terminus = [:validate_success_terminus, FIXME_SUCCESS = Circuit::Terminus::Success.new(semantic: :success), INVOKER___CIRCUIT_INTERFACE, {}]
  validate_failure_terminus = [:validate_failure_terminus, FIXME_FAILURE = Circuit::Terminus::Failure.new(semantic: :failure), INVOKER___CIRCUIT_INTERFACE, {}]

  validate_circuit = {
    run_checks => {Trailblazer::Activity::Right => title_length_ok, Trailblazer::Activity::Left => validate_failure_terminus},
    title_length_ok => {Trailblazer::Activity::Right => validate_success_terminus, Trailblazer::Activity::Left => validate_failure_terminus},
    # FIXME_SUCCESS => {},
    # FIXME_FAILURE => {},
  }
  validate_circuit = Circuit.new(map: validate_circuit, termini: [FIXME_SUCCESS, FIXME_FAILURE], start_task: run_checks)

  save_pipe = pipeline_circuit(
    [:input, Model___Input],
    [:invoke_callable, Save, INVOKER___STEP_INTERFACE],
    [:compute_binary_signal, ComputeBinarySignal],
    [:output, Model___Output],
  )

  # create_pipe = [
    model =    [:model,    model_pipe, Circuit::Processor,      {exec_context: Create.new.freeze},] # TODO: circuit_options should be set outside of Create, in the canonical invoke.
    validate = [:validate, validate_circuit, Circuit::Processor, {exec_context: Validate.new.freeze},]
    save =     [:save,     save_pipe, Circuit::Processor,       {}] # check that we don't have circuit_options anymore here?
  # ]

  create_success_terminus = [:create_success_terminus, CREATE_FIXME_SUCCESS = Circuit::Terminus::Success.new(semantic: :success), INVOKER___CIRCUIT_INTERFACE, {}]
  create_failure_terminus = [:create_failure_terminus, CREATE_FIXME_FAILURE = Circuit::Terminus::Failure.new(semantic: :failure), INVOKER___CIRCUIT_INTERFACE, {}]



  create_circuit = {
    model => {Trailblazer::Activity::Right => validate, Trailblazer::Activity::Left => create_failure_terminus}, # DISCUSS: reuse termini?
    validate => {FIXME_SUCCESS => save, FIXME_FAILURE => create_failure_terminus},
    save => {Trailblazer::Activity::Right => create_success_terminus, Trailblazer::Activity::Left => create_failure_terminus},
  }

  create_circuit = Circuit.new(map: create_circuit, termini: [CREATE_FIXME_SUCCESS, CREATE_FIXME_FAILURE], start_task: model)

  ctx = {params: {id: 1}}
  create_ctx = {
    # exec_context:     Create.new,
    application_ctx:  ctx
  }

  # validation error:
  ctx, signal = Circuit::Processor.(create_circuit, create_ctx)

  assert_equal ctx[:application_ctx], {:params=>{:id=>1}, :model=>"Object 1", :errors=>["Object 1", :song]}
  assert_equal ctx.keys, [:application_ctx, :exec_context]
  assert_equal signal, CREATE_FIXME_FAILURE

  # success:
  ctx, signal = Circuit::Processor.(create_circuit, {application_ctx: _ctx = {params: {song: {title: "Uwe"}, id: 1}}})

  assert_equal ctx[:application_ctx], {:params=>{:song=>{title: "Uwe"}, id: 1}, :model=>"Object 1", :save=>"Object 1"}
  assert_equal signal, CREATE_FIXME_SUCCESS
  assert_equal ctx.keys, [:application_ctx, :exec_context]

raise



  save_pipe = [
    a = [:input, Model___Input, INVOKER___CIRCUIT_INTERFACE, {}],

    b= [:invoke_callable, Save, INVOKER___STEP_INTERFACE, {}],
    c= [:compute_binary_signal, ComputeBinarySignal, INVOKER___CIRCUIT_INTERFACE, {}],

    d =[:output, Model___Output, INVOKER___CIRCUIT_INTERFACE, {}],
  ]


  save_circuit = {
    a => {nil => b},
    b => {nil => c},
    c => {Trailblazer::Activity::Right => d},
    # d => {Trailblazer::Activity::Right => create_success_terminus},
  }

  save_circuit = Circuit.new(map: save_circuit, termini: [Model___Output], start_task: a)

  ctx, signal = Circuit::Processor.(save_circuit, {application_ctx: {params: {}, model: Object}})
  ctx, signal = Pipeline::Processor.(save_pipe, {application_ctx: {params: {}, model: Object}})
  # raise ctx.inspect

    ## Benchmark circuit vs pipe.
    #
    # require "benchmark/ips"
    # Benchmark.ips do |x|
    #   x.report("circuit") { ctx, signal = Circuit::Processor.(save_circuit, {application_ctx: {params: {}, model: Object}}) }
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
