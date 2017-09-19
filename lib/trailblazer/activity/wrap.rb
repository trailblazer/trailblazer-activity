class Trailblazer::Activity
  module Wrap
    # The runner is passed into Activity#call( runner: Runner ) and is called for every task in the circuit.
    # Its primary job is to actually `call` the task.
    #
    # Here, we extend this, and wrap the task `call` into its own pipeline, so we can add external behavior per task.
    module Runner
      # @api private
      # Runner signature: call( task, direction, options, flow_options, static_wraps )
      # def self.call(task, direction, options, flow_options, static_wraps = Hash.new(Wrap.initial_activity))
      #
      # @interface Runner
      def self.call(task, (options, flow_options, static_wraps, *args), wrap_runtime: raise, **circuit_options)
        wrap_ctx   = { task: task }

        task_wrap_activity = apply_wirings(task, static_wraps, wrap_runtime)

        # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task) id: "task_wrap.call_task"
        #   |-- Trace.capture_return [optional]
        #   |-- Wrap::End
        # Pass empty flow_options to the task_wrap, so it doesn't infinite-loop.

        # We save all original args passed into this Runner.call, because we want to return them later after this wrap
        # is finished.
        original_args = [ [options, flow_options, static_wraps, *args], circuit_options.merge( wrap_runtime: wrap_runtime ) ]

        # call the wrap for the task.
        wrap_end_signal, (wrap_ctx, original_args) = task_wrap_activity.(
          [
            wrap_ctx,
            original_args,
          ]
        )

        [ wrap_ctx[:result_direction], *original_args ] # return everything plus the static_wraps for the next task in the circuit.
      end

      private

      # Compute the task's wrap by applying alterations both static and from runtime.
      def self.apply_wirings(task, wrap_static, wrap_runtime)
        wrap_activity = wrap_static[task]   # find static wrap for this specific task, or default wrap activity.

        # Apply runtime alterations.
        # Grab the additional wirings for the particular `task` from `wrap_runtime` (returns default otherwise).
        wrap_activity = Trailblazer::Activity.merge(wrap_activity, wrap_runtime[task])
      end
    end # Runner

    # The call_task method implements one default step `Call` in the Wrap::Activity circuit.
    # It calls the actual, wrapped task.
    def self.call_task((wrap_ctx, original_args), **circuit_options)
      task  = wrap_ctx[:task]

      # Call the actual task we're wrapping here.
      puts "~~~~wrap.call: #{task} #{circuit_options}"
      wrap_ctx[:result_direction], options, _ = task.( *original_args ) # FIXME: what about _ flow_options?

      [ Trailblazer::Circuit::Right, [ wrap_ctx, original_args ], **circuit_options ]
    end

    Call = method(:call_task)

    # Wrap::Activity is the actual circuit that implements the Task wrap. This circuit is
    # also known as `task_wrap`.
    #
    # Example with tracing:
    #
    #   |-- Start
    #   |-- Trace.capture_args   [optional]
    #   |-- Call (call actual task)
    #   |-- Trace.capture_return [optional]
    #   |-- End

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
          [ :insert_before!, "End.default", node: [ Call, id: "task_wrap.call_task" ], outgoing: [ Trailblazer::Circuit::Right, {} ], incoming: ->(*) { true } ]
        ]
      )
    end
  end
end
