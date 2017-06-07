module Trailblazer
  class Circuit
    # Trace#call will call the activities and trace what steps are called, options passed,
    # and the order and nesting.
    #
    #   stack, _ = Trailblazer::Circuit::Trace.(activity, activity[:Start], { id: 1 })
    #   puts Trailblazer::Circuit::Present.tree(stack) # renders the trail.
    module Trace
      def self.call(activity, direction, options, flow_options={})
        tracing_flow_options = {
          runner:           Activity::Wrapped::Runner,
          stack:            Trace::Stack.new,
          wrap_alterations: Activity::Wrapped::Alterations.new(Trace.Alterations),
          task_wraps:       Activity::Wrapped::Wraps.new(Activity::Wrapped::Activity),
          debug: {}, # TODO: set that in Activity::call?
        }

        direction, options, flow_options = activity.( direction, options, tracing_flow_options.merge(flow_options) )

        return flow_options[:stack].to_a, direction, options, flow_options
      end

      # Default tracing tasks to be plugged into the wrap circuit.
      def self.Alterations
        [
        ->(wrap_circuit) { Activity::Before( wrap_circuit, Activity::Wrapped::Call,           Trace.method(:capture_args),   direction: Right ) },
        ->(wrap_circuit) { Activity::Before( wrap_circuit, Activity::Wrapped::Activity[:End], Trace.method(:capture_return), direction: Right ) },
        ]
      end

      def self.capture_args(direction, options, flow_options, wrap_config, original_flow_options)
        original_flow_options[:stack].indent!

        original_flow_options[:stack] << [ wrap_config[:task], :args, nil, options.dup, original_flow_options[:debug] ]

        [ direction, options, flow_options, wrap_config, original_flow_options ]
      end

      def self.capture_return(direction, options, flow_options, wrap_config, original_flow_options)
        original_flow_options[:stack] << [ wrap_config[:task], :return, flow_options[:result_direction], options.dup ]

        original_flow_options[:stack].unindent!

        [ direction, options, flow_options, wrap_config, original_flow_options ]
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
