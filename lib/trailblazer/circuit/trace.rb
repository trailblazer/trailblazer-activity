module Trailblazer
  class Circuit
    # #   direction, result = circuit.( circuit[:Start], options, runner: Circuit::Trace.new, stack: [] )

    # # Every `activity.call` is considered nested
    # class Trace
    #   # Trace is passed in as the `:runner` into Circuit#call and is called per task.
    #   def call(activity, direction, args, debug:raise, stack:raise, **flow_options)
    #     activity_name, _ = debug[activity]
    #     activity_name ||= activity

    #     # Use Circuit::Run to actually call the task.
    #     direction, options, _flow_options = Run.(activity, direction, args, flow_options.merge(stack: []))

    #     # TODO: fix the inspect, we need a snapshot, deep-nested.
    #     stack << [activity_name, activity, direction, options, options.inspect, _flow_options[:stack].any? ? _flow_options[:stack] : nil ]

    #     return direction, options, _flow_options.merge(stack: stack, debug: debug)
    #   end
    # end # Trace

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
    end
  end
end
