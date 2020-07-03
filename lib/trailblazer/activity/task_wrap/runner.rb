class Trailblazer::Activity
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
      def self.call(task, args, circuit_options)
        wrap_ctx = { task: task }

        # this pipeline is "wrapped around" the actual `task`.
        task_wrap_pipeline = merge_static_with_runtime(task, **circuit_options) || raise

        # We save all original args passed into this Runner.call, because we want to return them later after this wrap
        # is finished.
        original_args = [ args, circuit_options ]

        # call the wrap {Activity} around the task.
        wrap_ctx, _ = task_wrap_pipeline.(wrap_ctx, original_args) # we omit circuit_options here on purpose, so the wrapping activity uses the default, plain Runner.

        # don't return the wrap's end signal, but the one from call_task.
        # return all original_args for the next "real" task in the circuit (this includes circuit_options).

        return wrap_ctx[:return_signal], wrap_ctx[:return_args]
      end


      # Compute the task's wrap by applying alterations both static and from runtime.
      #
      # NOTE: this is for performance reasons: we could have only one hash containing everything but that'd mean
      # unnecessary computations at `call`-time since steps might not even be executed.
      # TODO: make this faster.
      private_class_method def self.merge_static_with_runtime(task, wrap_runtime:, **circuit_options)
        static_wrap = TaskWrap.wrap_static_for(task, **circuit_options) # find static wrap for this specific task [, or default wrap activity].

        # Apply runtime alterations.
        # Grab the additional wirings for the particular `task` from `wrap_runtime`.
        (dynamic_wrap = wrap_runtime[task]) ? dynamic_wrap.(static_wrap) : static_wrap
      end
    end # Runner

    # Retrieve the static wrap config from {activity}.
    def self.wrap_static_for(task, activity:, **)
      wrap_static = activity[:wrap_static]
      wrap_static[task] or raise "#{task}"
    end
  end
end
