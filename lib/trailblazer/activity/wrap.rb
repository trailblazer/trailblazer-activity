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
      def self.call(task, (options, flow_options, static_wraps, *args), **circuit_options)
        wrap_config   = { task: task }
        runtime_wraps = flow_options[:wrap_runtime] || raise("Please provide :wrap_runtime")

        task_wrap_activity = apply_wirings(task, static_wraps, runtime_wraps)

        # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task) id: "task_wrap.call_task"
        #   |-- Trace.capture_return [optional]
        #   |-- Wrap::End
        # Pass empty flow_options to the task_wrap, so it doesn't infinite-loop.

        # call the wrap for the task.
        wrap_end_signal, (a, b, wrap_config, original_args) = task_wrap_activity.( [ {} , {} , wrap_config, [options, flow_options, static_wraps] ], circuit_options )

        [ wrap_config[:result_direction], [*original_args, static_wraps], circuit_options ] # return everything plus the static_wraps for the next task in the circuit.
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
    def self.call_task((options, flow_options, wrap_config, original_args), **circuit_options)
      task  = wrap_config[:task]

      # Call the actual task we're wrapping here.
      puts "~~~~wrap.call: #{task} #{circuit_options}"
      wrap_config[:result_direction], options, _ = task.( original_args, **circuit_options ) # FIXME: what about _ flow_options?

      [ Trailblazer::Circuit::Right, [options, flow_options, wrap_config, original_args], **circuit_options ]
    end

    Call = method(:call_task)

    # class End < Trailblazer::Circuit::End
    #   def call((options, flow_options, wrap_config, *args))
    #     [ wrap_config[:result_direction],[ options, flow_options] ] # note how we don't return the appended internal args.
    #   end
    # end

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
