class Trailblazer::Circuit
  module Wrap
    # The runner is passed into Circuit#call( runner: Runner ) and is called for every task in the circuit.
    # Its primary job is to actually `call` the task.
    #
    # Here, we extend this, and wrap the task `call` into its own pipeline, so we can add external behavior per task.
    module Runner
      NIL_WRAPS      = "Please provide :wrap_static"  # here for Ruby 2.0 compat.
      NIL_ALTERATION = "Please provide :wrap_runtime" # here for Ruby 2.0 compat.

      # @api private
      def self.call(task, direction, options, wrap_static:raise(NIL_WRAPS), wrap_runtime:raise(NIL_ALTERATION), **flow_options)
        task_wrap   = apply_alterations(task, wrap_static, wrap_runtime)

        wrap_config = { task: task }

        # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task)
        #   |-- Trace.capture_return [optional]
        #   |-- End
        # Pass empty flow_options to the task_wrap, so it doesn't infinite-loop.
        task_wrap.( task_wrap[:Start], options, {}, wrap_config, flow_options.merge( wrap_static: wrap_static, wrap_runtime: wrap_runtime) )
      end

      private

      # Compute the task's wrap by applying alterations both static and from runtime.
      def self.apply_alterations(task, wrap_static, wrap_runtime, default_wrap=Activity)
        task_wrap = wrap_static.(task, Activity)   # find static wrap for this specific task, Activity is the default wrap.
        task_wrap = wrap_runtime.(task, task_wrap) # apply runtime alterations.
      end
    end # Runner

    # The call_task method implements one default step `Call` in the Wrap::Activity circuit.
    # It calls the actual, wrapped task.
    def self.call_task(direction, options, flow_options, wrap_config, original_flow_options)
      task  = wrap_config[:task]

      # Call the actual task we're wrapping here.
      wrap_config[:result_direction], options, flow_options = task.( direction, options, original_flow_options )

      [ direction, options, flow_options, wrap_config, original_flow_options ]
    end

    Call = method(:call_task)

    class End < Trailblazer::Circuit::End
      def call(direction, options, flow_options, wrap_config, *args)
        [ wrap_config[:result_direction], options, flow_options ] # note how we don't return the appended internal args.
      end
    end

    # Wrap::Activity is the actual circuit that implements the Task wrap. This circuit is
    # also known as `task_wrap`.
    #
    # Example with tracing:
    #
    #   |-- Start
    #   |-- Trace.capture_args   [optional]
    #   |-- Call (call actual task)
    #   |-- Trace.capture_return [optional]
    #   |-- End
    Activity = Trailblazer::Circuit::Activity({ id: "task.wrap" }, end: { default: End.new(:default) }) do |act|
      {
        act[:Start] => { Right => Call }, # see Wrap::call_task
        Call        => { Right => act[:End] },
      }
    end # Activity

    # Alterations#call finds alterations for `task` and applies them to `task_wrap`.
    # Each alteration receives the result of the former one, starting with `task_wrap`.
    #
    # This is used to add tracing steps, input/output contracts, and more at runtime,
    # or to maintain specific static task_wraps, as for each step in an operation.
    #
    # Note that an alteration doesn't have to respect its `task_wrap` and can simply return
    # an arbitrary Circuit.
    #
    # === DESIGN
    # By moving the "default" decision to this object, you can control what task gets wrapped
    # with what wrap, allowing you to only wrap "focussed" tasks, for example.
    #
    # It also allows to inject, say, a tracing alteration that is only applied to a specific task
    # and returns all others unchanged.
    class Alterations
      PassThrough = ->(task_wrap) { task_wrap }

      def initialize(map: {}, default: [ PassThrough ])
        @default_alterations, @map = default, map
      end

      # @returns Circuit
      def call(task, target_wrap)
        get(task). # list of alterations.
          inject(target_wrap) { |circuit, alteration| alteration.(circuit) }
      end

      private

      def get(task)
        @map[task] || @default_alterations
      end
    end
  end
end
