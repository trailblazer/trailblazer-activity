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
      def self.call(task, ctx, flow_options, circuit_options)
        # Since we're in a taskWrap-specific environment here, the ctx is a different one.
        wrap_ctx = {
          task: task,
          application_ctx: ctx,
          application_circuit_options: circuit_options,
        }

        # this pipeline is "wrapped around" the actual `task`.
        task_wrap_pipeline = merge_static_with_runtime(task, **circuit_options) || raise

        wrap_ctx, flow_options = task_wrap_pipeline.(wrap_ctx, flow_options, circuit_options) # FIXME: return those flow_options!

        # Both {:return_signal} and {:return_ctx} are set in {#call_task}, the very tw step that
        # executes the actual task which is wrapped.
        return wrap_ctx[:return_signal], wrap_ctx[:return_ctx], flow_options
      end

      # Compute the task's wrap by applying alterations both static and from runtime.
      #
      # NOTE: this is for performance reasons: we could have only one hash containing everything but that'd mean
      # unnecessary computations at `call`-time since steps might not even be executed.
      # TODO: make this faster.
      # private_class_method
      def self.merge_static_with_runtime(task, wrap_runtime:, activity:, **circuit_options)
        static_task_wrap = TaskWrap.wrap_static_for(task, activity) # find static wrap for this specific task [, or default wrap activity].

        # Apply runtime alterations.
        # Grab the additional task_wrap extensions for the particular {task} from {:wrap_runtime}.
        # DISCUSS: should we allow an array of runtime extensions? And use {Normalizer::TaskWrap.compile_task_wrap_ary_from_extensions} logic?
        (dynamic_wrap = wrap_runtime[task]) ? dynamic_wrap.(static_task_wrap) : static_task_wrap
      end
    end # Runner

    # Retrieve the static wrap config from {activity}.
    # @private
    def self.wrap_static_for(task, activity)
      activity.to_h
        .fetch(:config)
        .fetch(:wrap_static)[task] # the {wrap_static} for {task}.
    end
  end
end
