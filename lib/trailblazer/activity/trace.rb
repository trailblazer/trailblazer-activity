module Trailblazer
  class Activity
    # Trace#call will call the activities and trace what steps are called, options passed,
    # and the order and nesting.
    #
    #   stack, _ = Trailblazer::Activity::Trace.(activity, activity[:Start], { id: 1 })
    #   puts Trailblazer::Activity::Present.tree(stack) # renders the trail.
    #
    # Hooks into the TaskWrap.
    module Trace
      def self.call(activity, (options), *args, &block)
        tracing_flow_options = {
          stack:        Trace::Stack.new,
          # Note that we don't pass :wrap_static here, that's handled by Task.__call__.
          introspection:        {}, # usually set that in Activity::call.
        }

        tracing_circuit_options = {
          runner:       Wrap::Runner,
          wrap_runtime: ::Hash.new(Trace.wirings), # FIXME: this still overrides existing wrap_runtimes.
          wrap_static:  ::Hash.new( Trailblazer::Activity::Wrap.initial_activity ) # FIXME
        }

        last_signal, (options, flow_options) = call_circuit( activity, [
          options,
          # tracing_flow_options.merge(flow_options),
          tracing_flow_options,
        ], tracing_circuit_options, &block )

        return flow_options[:stack].to_a, last_signal, options, flow_options
      end

      # TODO: test alterations with any wrap_circuit.
      def self.call_circuit(activity, *args, &block)
        return activity.(*args) unless block
        block.(activity, *args)
      end

      # Default tracing tasks to be plugged into the wrap circuit.
      def self.wirings
        [
          [ :insert_before!, "task_wrap.call_task", node: [ Trace.method(:capture_args),   id: "task_wrap.capture_args" ], outgoing: [ Circuit::Right, {} ], incoming: ->(*) { true } ],
          [ :insert_before!, "End.default",      node: [ Trace.method(:capture_return), id: "task_wrap.capture_return" ], outgoing: [ Circuit::Right, {} ], incoming: ->(*) { true } ],
        ]
      end

      # def self.capture_args(direction, options, flow_options, wrap_config, original_flow_options)
      def self.capture_args((wrap_config, original_args), **circuit_options)
        (original_options, original_flow_options, _) = original_args[0]

        original_flow_options[:stack].indent!

        original_flow_options[:stack] << [ wrap_config[:task], :args, nil, {}, original_flow_options[:introspection] ]

        [ Circuit::Right, [wrap_config, original_args ], **circuit_options ]
      end

      def self.capture_return((wrap_config, original_args), **circuit_options)
        (original_options, original_flow_options, _) = original_args[0]

        original_flow_options[:stack] << [ wrap_config[:task], :return, wrap_config[:result_direction], {} ]

        original_flow_options[:stack].unindent!


        [ Circuit::Right, [wrap_config, original_args ], **circuit_options ]
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
