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
            plus_poles:       Magnetic::PlusPoles.initial( :success => Magnetic::Builder::Path.default_outputs[:success] ) # DefaultNormalizer doesn't give us default PlusPoles.
          )

          task TaskWrap.method(:call_task), id: "task_wrap.call_task" # ::call_task is defined in task_wrap/call_task.
        end
      end

      # Compute runtime arguments necessary to execute a taskWrap per task of the activity.
      def self.invoke(activity, args, wrap_runtime: {}, **circuit_options)
        circuit_options = circuit_options.merge(
          runner:       TaskWrap::Runner,
          wrap_runtime: wrap_runtime,

          activity: {}, # for Runner
        )

        # signal, (ctx, flow), circuit_options =
        Runner.(activity, args, circuit_options)
      end
    end # TaskWrap
  end
end
