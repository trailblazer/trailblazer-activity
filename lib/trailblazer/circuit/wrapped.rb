class Trailblazer::Circuit
  module Activity::Wrapped
    # Input  = ->(direction, options, flow_options) { [direction, options, flow_options] }

    # FIXME: wrong direction and flow_options here!
    def self.call_activity(direction, options, flow_options, wrap_config, original_flow_options)
      task  = wrap_config[:step]

      # Call the actual task we're wrapping here.
      wrap_config[:result_direction], options, flow_options = task.( direction, options, original_flow_options )

      [ direction, options, flow_options, wrap_config, original_flow_options ]
    end

    Call = method(:call_activity)

    # Output = ->(direction, options, flow_options) { [direction, options, flow_options] }

    class End < Trailblazer::Circuit::End
      def call(direction, options, flow_options, wrap_config, *args)
        [ wrap_config[:result_direction], options, flow_options, wrap_config, *args ]
      end
    end

    Activity = Trailblazer::Circuit::Activity({ id: "task.wrap" }, end: { default: End.new(:default) }) do |act|
      {
        act[:Start]          => { Right => Call },                  # options from outside
        # Input                => { Circuit::Right => Trace::CaptureArgs },
        # MyInject               => { Circuit::Right => Trace::CaptureArgs },
        # Trace::CaptureArgs   => { Circuit::Right => Call  },
        Call                 => { Right => act[:End] },
        # Trace::CaptureReturn => { Circuit::Right => Output },
        # Output               => { Circuit::Right => act[:End] }
      }
    end

    # Find the respective wrap per task, and run it.
    class Runner
      # private flow_options[ :step_runners ]
      def self.call(task, direction, options, flow_options)
        # TODO: test this decider!
        task_wrap = flow_options[:step_runners][task] || flow_options[:step_runners][nil] # DISCUSS: default could be more explicit@

        # we can't pass :runner in here since the Step::Pipeline would call itself again, then.
        # However, we need the runner in nested activities.
        wrap_config = { step: task }

        # Call the task_wrap circuit:
        #   |-- Start
        #   |-- Trace.capture_args   [optional]
        #   |-- Call (call actual task)
        #   |-- Trace.capture_return [optional]
        #   |-- End
        # Pass empty flow_options to the task_wrap, so it doesn't infinite-loop.
        task_wrap.( task_wrap[:Start], options, {}, wrap_config, flow_options ) # all tasks in Wrap have to implement this signature.
      end
    end # Runner
  end
end
