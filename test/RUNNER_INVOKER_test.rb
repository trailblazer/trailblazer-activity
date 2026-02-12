require "test_helper"

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
          return ctx, signal if termini.include?(task)

          if next_task_cfg = next_for(map, task_cfg, signal)
            task_cfg = next_task_cfg
            puts "@@@@@ =========> #{next_task_cfg.inspect}"
          else
            raise
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

  class Pipeline < Struct.new(:sequence)
    class Processor
      def self.call(sequence, ctx, **)
        signal = nil

        sequence.each do |_id, task, invoker, circuit_options_to_merge = {}|
          puts "pipe @@@@@ #{_id.inspect} "

          ctx = ctx.merge(circuit_options_to_merge)

          ctx, signal = invoker.(task, ctx, **ctx)
        end

        return ctx, signal
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
    def self.call(ctx, flow_options, circuit_options, task:, **kwargs)
      result = task.(ctx, **ctx.to_h)

      raise "FIXME: binary"
    end
  end

  class INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT
    def self.call(task, ctx, exec_context:, application_ctx:, **)

      result = exec_context.send(task, application_ctx, **application_ctx.to_h)

      return ctx.merge(value: result), nil # DISCUSS: value
    end
  end

  class ComputeBinarySignal
    def self.call(ctx, value:, **)
      signal = value ? Trailblazer::Activity::Right : Trailblazer::Activity::Left

      ctx[:signal] = signal

      return ctx, signal
    end
  end

  class Model___Input
    def self.call(ctx, exec_context:, **)
      ctx = Trailblazer::Context(ctx)

      return ctx, nil
    end
  end

  class Model___Output
    def self.call(ctx, signal:, **)
      ctx, _ = ctx.decompose
      return ctx, signal
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

  model_pipe = [
    [:input, Model___Input, INVOKER___CIRCUIT_INTERFACE],

    [:invoke_instance_method, :model, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT, {task: :model}],
    [:compute_binary_signal, ComputeBinarySignal, INVOKER___CIRCUIT_INTERFACE],

    [:output, Model___Output, INVOKER___CIRCUIT_INTERFACE],
  ]

  run_checks_pipe = [
    [:input, Model___Input, INVOKER___CIRCUIT_INTERFACE],

    [:invoke_instance_method, :run_checks, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT],
    [:compute_binary_signal, ComputeBinarySignal, INVOKER___CIRCUIT_INTERFACE],

    [:output, Model___Output, INVOKER___CIRCUIT_INTERFACE],
  ]

  title_length_ok_pipe = [
    [:input, Model___Input, INVOKER___CIRCUIT_INTERFACE],

    [:invoke_instance_method, :title_length_ok?, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT],
    [:compute_binary_signal, ComputeBinarySignal, INVOKER___CIRCUIT_INTERFACE],

    [:output, Model___Output, INVOKER___CIRCUIT_INTERFACE],
  ]

  run_checks      = [:run_checks, run_checks_pipe, Pipeline::Processor, {}]
  title_length_ok = [:title_length_ok?, title_length_ok_pipe, Pipeline::Processor, {}]
  success_terminus = [:success_terminus, FIXME_SUCCESS = Circuit::Terminus::Success.new(semantic: :success), INVOKER___CIRCUIT_INTERFACE, {}]
  failure_terminus = [:failure_terminus, FIXME_FAILURE = Circuit::Terminus::Failure.new(semantic: :failure), INVOKER___CIRCUIT_INTERFACE, {}]

  validate_circuit = {
    run_checks => {Trailblazer::Activity::Right => title_length_ok, Trailblazer::Activity::Left => failure_terminus},
    title_length_ok => {Trailblazer::Activity::Right => success_terminus, Trailblazer::Activity::Left => failure_terminus},
    # FIXME_SUCCESS => {},
    # FIXME_FAILURE => {},
  }
  validate_circuit = Circuit.new(map: validate_circuit, termini: [FIXME_SUCCESS, FIXME_FAILURE], start_task: run_checks)

  create_pipe = [
    [:model,    model_pipe, Pipeline::Processor,      {exec_context: Create.new.freeze},], # TODO: circuit_options should be set outside of Create, in the canonical invoke.
    [:validate, validate_circuit, Circuit::Processor, {exec_context: Validate.new.freeze},]

  ]

  ctx = {params: {id: 1}}
  create_ctx = {
    # exec_context:     Create.new,
    application_ctx:  ctx
  }


  ctx, signal = Pipeline::Processor.(create_pipe, create_ctx)

  assert_equal ctx[:application_ctx], {:params=>{:id=>1}, :model=>"Object 1", :errors=>["Object 1", :song]}
  assert_equal ctx.keys, [:application_ctx, :exec_context]
  assert_equal signal, FIXME_FAILURE

  ctx, signal = Pipeline::Processor.(create_pipe, {application_ctx: _ctx = {params: {song: {title: "Uwe"}}}})

  assert_equal signal, FIXME_SUCCESS
  assert_equal ctx[:application_ctx], _ctx
  assert_equal ctx.keys, [:application_ctx, :exec_context]

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
