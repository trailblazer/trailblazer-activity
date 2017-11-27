class Trailblazer::Activity
  module Wrap
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
        task Wrap.method(:call_task), id: "task_wrap.call_task"
      end
    end
  end
end
