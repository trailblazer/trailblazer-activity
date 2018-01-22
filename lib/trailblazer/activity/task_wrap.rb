class Trailblazer::Activity < Module
    #
    # Example with tracing:
    #
          # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task) id: "task_wrap.call_task"
        #   |-- Trace.capture_return [optional]
        #   |-- Wrap::End
  module TaskWrap
    # The actual activity that implements the taskWrap.
    def self.initial_activity
      Module.new do
        extend Trailblazer::Activity::Path( name: "taskWrap", normalizer_class: Magnetic::DefaultNormalizer )

        task TaskWrap.method(:call_task), id: "task_wrap.call_task" # ::call_task is defined in task_wrap/call_task.
      end
    end

    def self.arguments_for_call(activity, (options, flow_options), **circuit_args)
      circuit_args = circuit_args.merge(
        runner:       TaskWrap::Runner,
        wrap_runtime: circuit_args[:wrap_runtime] || {}, # FIXME:this sucks. (was:) this overwrites wrap_runtime from outside.
        wrap_static:  activity[:static_task_wrap],
      )

      return activity, [ options, flow_options ], circuit_args
    end

    module NonStatic
      def self.arguments_for_call(activity, (options, flow_options), **circuit_args)
        circuit_args = circuit_args.merge(
          runner:       TaskWrap::Runner,
          wrap_runtime: circuit_args[:wrap_runtime] || {}, # FIXME:this sucks. (was:) this overwrites wrap_runtime from outside.
          wrap_static:  ::Hash.new(TaskWrap.initial_activity), # add a default static wrap.
        )

        return activity, [ options, flow_options ], circuit_args
      end
    end

    def self.included(includer) # TODO: make this unnecessary.
      includer[:static_task_wrap] = ::Hash.new(TaskWrap.initial_activity)
    end

    # better: MyClass < Activity(TaskWrap, ...)
  end
end
