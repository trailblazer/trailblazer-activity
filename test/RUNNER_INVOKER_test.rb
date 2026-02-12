require "test_helper"

class RunnerInvokerTest < Minitest::Spec
it do
  # We start with NO #call methods!
  class Circuit < Struct.new(:map, :start_task, :termini)

  end

  class Pipeline < Struct.new(:sequence)
    class Processor
      def self.call(sequence, ctx, **)
        signal = nil

        sequence.each do |_id, task, invoker, circuit_options_to_merge = {}|
          puts "@@@@@ #{task.inspect} --> #{invoker} -------> #{ctx.to_h}"

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
      # ctx[:exec_context] = ComputeBinarySignal
      # ctx[:original_exec_context] = exec_context

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

  model_pipe = [
    [:input, Model___Input, INVOKER___CIRCUIT_INTERFACE],

    [:invoke_instance_method, :model, INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT, {task: :model}],
    [:compute_binary_signal, ComputeBinarySignal, INVOKER___CIRCUIT_INTERFACE],

    [:output, Model___Output, INVOKER___CIRCUIT_INTERFACE],
  ]

  create_pipe = [
    [
      :model, model_pipe, Pipeline::Processor, {exec_context: Create.new.freeze}
    ],

  ]

  ctx = {params: {id: 1}}
  create_ctx = {
    # exec_context:     Create.new,
    application_ctx:  ctx
  }

  # ctx, signal = Pipeline::Processor.(model_pipe, create_ctx)
  ctx, signal = Pipeline::Processor.(create_pipe, create_ctx)

  assert_equal ctx[:application_ctx], {:params=>{:id=>1}, :model=>"Object 1"}
  assert_equal ctx.keys, [:application_ctx, :exec_context]
  assert_equal signal, Trailblazer::Activity::Right
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
