module Trailblazer
  class Activity < Module
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
          extend Trailblazer::Activity::Path(
            name:             "taskWrap",
            normalizer_class: Magnetic::DefaultNormalizer,
            plus_poles:       Magnetic::PlusPoles.initial( Magnetic::Builder::Path.DefaultOutputs[0..0] ) # DefaultNormalizer doesn't give us default PlusPoles.
          )

          task TaskWrap.method(:call_task), id: "task_wrap.call_task" # ::call_task is defined in task_wrap/call_task.
        end
      end

      # Compute runtime arguments necessary to execute a taskWrap per task of the activity.
      def self.arguments_for_call(activity, (options, flow_options), **circuit_options)
        circuit_options = circuit_options.merge(
          runner:       TaskWrap::Runner,
          wrap_runtime: circuit_options[:wrap_runtime] || {},
          wrap_static:  activity[:wrap_static] || {},
        )

        return activity, [ options, flow_options ], circuit_options
      end

      module NonStatic
        def self.arguments_for_call(activity, (options, flow_options), **circuit_options)
          circuit_options = circuit_options.merge(
            runner:       TaskWrap::Runner,
            wrap_runtime: circuit_options[:wrap_runtime] || {}, # FIXME:this sucks. (was:) this overwrites wrap_runtime from outside.
            wrap_static:  ::Hash.new(TaskWrap.initial_activity), # add a default static wrap.
          )

          return activity, [ options, flow_options ], circuit_options
        end
      end

      # better: MyClass < Activity(TaskWrap, ...)
    end
  end
end
