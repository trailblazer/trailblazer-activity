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

    # Activity = Trailblazer::Activity::Activity({ id: "task.wrap" }, end: { default: End.new(:default) }) do |act|
    #   {
    #     act[:Start] => { Right => Call }, # see Wrap::call_task
    #     Call        => { Right => act[:End] },
    #   }
    # end # Activity

    def self.initial_activity
      Trailblazer::Activity.from_wirings(
        [
          [ :attach!, target: [ Trailblazer::Circuit::End.new(:default), type: :event, id: "End.default" ], edge: [ Trailblazer::Circuit::Right, {} ] ],
          [ :insert_before!, "End.default", node: [ Wrap.method(:call_task), id: "task_wrap.call_task" ], outgoing: [ Trailblazer::Circuit::Right, {} ], incoming: ->(*) { true } ]
        ]
      )
    end
  end
end
