class Trailblazer::Circuit
  module Wrap
    # The runner is passed into Circuit#call( runner: Runner ) and is called for every task in the circuit.
    # Its primary job is to actually `call` the task.
    #
    # Here, we extend this, and wrap the task `call` into its own pipeline, so we can add external behavior per task.
    module Runner
      NIL_ALTERATION = "Please provide :wrap_runtime" # here for Ruby 2.0 compat.

      # @api private
      def self.call(task, direction, options, wrap_static: Hash.new(Wrap.initial_activity), wrap_runtime:raise(NIL_ALTERATION), **flow_options)
        task_wrap_activity   = apply_wirings(task, wrap_static, wrap_runtime)
        wrap_config = { task: task }

        # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task)
        #   |-- Trace.capture_return [optional]
        #   |-- End
        # Pass empty flow_options to the task_wrap, so it doesn't infinite-loop.
        task_wrap_activity.( nil, options, {}, wrap_config, flow_options.merge( wrap_static: wrap_static, wrap_runtime: wrap_runtime) )
      end

      private

      # Compute the task's wrap by applying alterations both static and from runtime.
      def self.apply_wirings(task, wrap_static, wrap_runtime)
        wrap_activity = wrap_static[task]   # find static wrap for this specific task, or default wrap activity.

        # Apply runtime alterations.
        # Grab the additional wirings for the particular `task` from `wrap_runtime` (returns default otherwise).
        wrap_activity = Trailblazer::Activity.merge(wrap_activity, wrap_runtime[task])
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
    # Activity = Trailblazer::Circuit::Activity({ id: "task.wrap" }, end: { default: End.new(:default) }) do |act|
    #   {
    #     act[:Start] => { Right => Call }, # see Wrap::call_task
    #     Call        => { Right => act[:End] },
    #   }
    # end # Activity

    def self.initial_activity
      Trailblazer::Activity.from_wirings(
        [
          [ :attach!, target: [ End.new(:default), type: :event, id: [:End, :default] ], edge: [ Right, {} ] ],
          [ :insert_before!, [:End, :default], node: [ Call, id: "task_wrap.call_task" ], outgoing: [ Right, {} ], incoming: ->(*) { true } ]
        ]
      )
    end
  end
end
