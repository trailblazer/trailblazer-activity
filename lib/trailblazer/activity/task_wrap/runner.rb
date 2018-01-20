module Trailblazer::Activity
  module TaskWrap
    # The runner is passed into Activity#call( runner: Runner ) and is called for every task in the circuit.
    # It runs the TaskWrap per task.
    #
    # (wrap_ctx, original_args), **wrap_circuit_options
    module Runner
      # Runner signature: call( task, direction, options, static_wraps )
      #
      # @api private
      # @interface Runner
      def self.call(task, args, wrap_runtime:, wrap_static:, **circuit_options)
        wrap_ctx = { task: task }

        # this activity is "wrapped around" the actual `task`.
        task_wrap_activity = merge_activity(task, wrap_static, wrap_runtime)

        # We save all original args passed into this Runner.call, because we want to return them later after this wrap
        # is finished.
        original_args = [ args, circuit_options.merge( wrap_runtime: wrap_runtime, wrap_static: wrap_static ) ]
        # call the wrap {Activity} around the task.
        wrap_end_signal, ( wrap_ctx, _ ) = task_wrap_activity.(
          [ wrap_ctx, original_args ] # we omit circuit_options here on purpose, so the wrapping activity uses the default, plain Runner.
        )
pp wrap_ctx

pp task_wrap_activity.decompose

        # don't return the wrap's end signal, but the one from call_task.
        # return all original_args for the next "real" task in the circuit (this includes circuit_options).

        [ wrap_ctx[:return_signal], wrap_ctx[:return_args] ]
      end

      private

      # Compute the task's wrap by applying alterations both static and from runtime.
      #
      # NOTE: this is for performance reasons: we could have only one hash containing everything but that'd mean
      # unnecessary computations at `call`-time since steps might not even be executed.
      # TODO: make this faster.
      def self.merge_activity(task, wrap_static, wrap_runtime)
        wrap_activity = wrap_static[task]   # find static wrap for this specific task, or default wrap activity.

        # Apply runtime alterations.
        # Grab the additional wirings for the particular `task` from `wrap_runtime` (returns default otherwise).
        wrap_runtime[task].any? ? Trailblazer::Activity::Path::Plan.merge(wrap_activity, wrap_runtime[task]) : wrap_activity
      end
    end # Runner
  end
end
