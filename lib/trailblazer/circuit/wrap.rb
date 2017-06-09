class Trailblazer::Circuit
  module Wrap
    # The runner is passed into Circuit#call( runner: Runner ) and is called for every task in the circuit.
    # Its primary job is to actually `call` the task.
    #
    # Here, we extend this, and wrap the task `call` into its own pipeline, so we can add external behavior per task.
    class Runner
      NIL_WRAPS      = "Please provide a :wrap_set"
      NIL_ALTERATION = "Please provide :wrap_alterations" # these are here for Ruby 2.0 compat.

      # @api private
      def self.call(task, direction, options, wrap_set:raise(NIL_WRAPS), wrap_alterations:raise(NIL_ALTERATION), **flow_options)
        task_wrap   = wrap_set.(task)                    # find wrap for this specific task.
        task_wrap   = wrap_alterations.(task, task_wrap) # apply alterations.

        wrap_config = { task: task }

        # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task)
        #   |-- Trace.capture_return [optional]
        #   |-- End
        # Pass empty flow_options to the task_wrap, so it doesn't infinite-loop.
        task_wrap.( task_wrap[:Start], options, {}, wrap_config, flow_options.merge( wrap_set: wrap_set, wrap_alterations: wrap_alterations) )
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

    # Wraps::call always returns a circuit, which is usually the specifically wrapped original task.
    #
    # === DESIGN
    # By moving the "default" decision to this object, you can control what task gets wrapped
    # with what wrap, allowing you to only wrap "focussed" tasks, for example.
    class Wraps
      def initialize(default, hash={})
        @default, @hash = default, hash
      end

      def call(task)
        get(task)
      end

      private

      def get(task)
        @hash.fetch(task) { @default }
      end
    end

    # Alterations::call finds alterations for `task` and apply them to `task_wrap`.
    # This usually means that tracing steps/tasks are added, input/output contracts added, etc.
    #
    # === DESIGN
    # By moving the "default" decision to this object, you can inject, say, a tracing alteration
    # that is only applied to a specific task and returns all others unchanged.
    class Alterations < Wraps
      def call(task, task_wrap)
        get(task).
          inject(task_wrap) { |circuit, alteration| alteration.(circuit) }
      end
    end
  end
end
