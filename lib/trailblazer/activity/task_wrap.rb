class Trailblazer::Activity
  module TaskWrap
    # Wrap::Activity is the actual circuit that implements the Task wrap. This circuit is
    # also known as `task_wrap`.
    #
    # Example with tracing:
    #
          # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task) id: "task_wrap.call_task"
        #   |-- Trace.capture_return [optional]
        #   |-- Wrap::End

    def self.initial_activity
      Magnetic::Builder::Path.plan do
        # Wrap.call_task is defined in wrap/call_task.
        task TaskWrap.method(:call_task), id: "task_wrap.call_task"
      end
    end

    def self.arguments_for_call(activity, (options, flow_options), **circuit_args)
      wrap_static = activity.static_task_wrap

      circuit_args = circuit_args.merge(
        runner:       TaskWrap::Runner,
                # FIXME: this sucks, why do we even need to pass an empty runtime there?
        wrap_runtime: circuit_args[:wrap_runtime] || ::Hash.new([]), # FIXME:this sucks. (was:) this overwrites wrap_runtime from outside.
        wrap_static:  wrap_static,
      )

      return [ options, flow_options ], circuit_args
    end

  end
end
