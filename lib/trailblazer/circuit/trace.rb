module Trailblazer
  class Circuit
    # Trace#call will call the activities and trace what steps are called, options passed,
    # and the order and nesting.
    #
    #   stack, _ = Trailblazer::Circuit::Trace.(activity, activity[:Start], { id: 1 })
    #   puts Trailblazer::Circuit::Present.tree(stack) # renders the trail.
    module Trace
      def self.call(activity, direction, options, flow_options={})
        # activity_wrap is the circuit/pipeline that wraps each step and implements tracing (and more, like input/output contracts, etc!).
        activity_wrap = Activity::Before( Activity::Wrapped::Activity, Activity::Wrapped::Call, Trace.method(:capture_args), direction: Right )
        activity_wrap = Activity::Before( activity_wrap, Activity::Wrapped::Activity[:End], Trace.method(:capture_return), direction: Right )

        step_runners = {
          nil   => activity_wrap, # call all steps with tracing.
        }

        tracing_flow_options = {
          runner:       Activity::Wrapped::Runner,
          stack:        Circuit::Trace::Stack.new,
          step_runners: step_runners,
          debug:        activity.circuit.instance_variable_get(:@name)
        }

        direction, options, flow_options = activity.( direction, options, tracing_flow_options.merge(flow_options) )

        return flow_options[:stack].to_a, direction, options, flow_options
      end

      def self.capture_args(direction, options, flow_options)
        flow_options[:stack].indent!

        flow_options[:stack] << [ flow_options[:step], :args, nil, options.dup, flow_options[:debug] ]

        [ direction, options, flow_options ]
      end

      def self.capture_return(direction, options, flow_options)
        flow_options[:stack] << [ flow_options[:step], :return, flow_options[:result_direction], options.dup ]

        flow_options[:stack].unindent!

        [ direction, options, flow_options ]
      end

      # Mutable/stateful per design. We want a (global) stack!
      class Stack
        def initialize
          @nested  = []
          @stack   = [ @nested ]
        end

        def indent!
          current << indented = []
          @stack << indented
        end

        def unindent!
          @stack.pop
        end

        def <<(args)
          current << args
        end

        def to_a
          @nested
        end

        private
        def current
          @stack.last
        end
      end # Stack
    end
  end
end
