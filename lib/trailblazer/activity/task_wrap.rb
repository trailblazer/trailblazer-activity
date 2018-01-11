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
        task TaskWrap.method(:call_task), id: "task_wrap.call_task" # ::call_task is defined in task_wrap/call_task.
      end
    end

    def self.arguments_for_call(activity, (options, flow_options), **circuit_args)
      circuit_args = circuit_args.merge(
        runner:       TaskWrap::Runner,
        wrap_runtime: circuit_args[:wrap_runtime] || ::Hash.new([]), # FIXME:this sucks. (was:) this overwrites wrap_runtime from outside.
        wrap_static:  activity.static_task_wrap,
      )

      return activity, [ options, flow_options ], circuit_args
    end

    module NonStatic
      def self.arguments_for_call(activity, (options, flow_options), **circuit_args)
        circuit_args = circuit_args.merge(
          runner:       TaskWrap::Runner,
          wrap_runtime: circuit_args[:wrap_runtime] || ::Hash.new([]), # FIXME:this sucks. (was:) this overwrites wrap_runtime from outside.
          wrap_static:  ::Hash.new(TaskWrap.initial_activity), # add a default static wrap.
        )

        return activity, [ options, flow_options ], circuit_args
      end
    end

    def self.included(includer)
      includer.extend(ClassMethods)
      includer.initialize_static_task_wrap!
    end

    # better: MyClass < Activity(TaskWrap, ...)

    module ClassMethods
      def initialize!(*)
        super # TODO: use Activity for that.

        initialize_static_task_wrap! # TODO: this sucks so much.
      end

      def static_task_wrap
        @static_task_wrap
      end

      def initialize_static_task_wrap!
        @static_task_wrap = ::Hash.new(TaskWrap.initial_activity)
      end
    end
  end
end
