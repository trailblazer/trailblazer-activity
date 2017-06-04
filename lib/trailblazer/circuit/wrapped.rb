class Trailblazer::Circuit
  module Activity::Wrapped
    # Input  = ->(direction, options, flow_options) { [direction, options, flow_options] }

    # FIXME: wrong direction and flow_options here!
    def self.call_activity(direction, options, flow_options)
      step  = flow_options[:step]

      # The called activity might add stuff to flow_options that we don't want to pass on.
      # That's why we wrap it in a Context.
      ctx = Trailblazer::Context.new(flow_options)

      # inject runner and debug tmp variables for the call.
      if step.instance_of?(Nested)
        ctx[:runner] = ctx[:_runner]
        ctx[:debug]  = step.activity.circuit.instance_variable_get(:@name)
      end

      flow_options[:result_direction], options, flow_options = step.( direction, options, ctx )

      [ direction, options, ctx.Build { |original, _| original } ]
    end

    Call = method(:call_activity)

    # Output = ->(direction, options, flow_options) { [direction, options, flow_options] }

    class End < Trailblazer::Circuit::End
      def call(direction, options, flow_options)
        [flow_options[:result_direction], options, flow_options]
      end
    end

    Activity = Trailblazer::Circuit::Activity({ id: "activity.wrap" }, end: { default: End.new(:default) }) do |act|
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

    # Find the respective wrap per step, and run it.
    class Runner
      def self.call(step, direction, options, runner:, **flow_options)
        step_runner = flow_options[:step_runners][step] || flow_options[:step_runners][nil] # DISCUSS: default could be more explicit@

        # we can't pass :runner in here since the Step::Pipeline would call itself again, then.
        # However, we need the runner in nested activities.
        pipeline_options = flow_options.merge( step: step, _runner: Runner )

        # Circuit#call
        step_runner.( step_runner[:Start], options, pipeline_options )
      end
    end # Runner
  end
end
