module Trailblazer
  class Circuit
    # Insert the trace steps as follows:
    #
    #   model_pipe = Circuit::Activity::Before( Pipeline::Step, Pipeline::Call, Trace.method(:capture_args), direction: Circuit::Right )
    module Trace
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
