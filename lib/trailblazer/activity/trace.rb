module Trailblazer
  class Activity < Module   # Trace#call will call the activities and trace what steps are called, options passed,
    # and the order and nesting.
    #
    #   stack, _ = Trailblazer::Activity::Trace.(activity, activity[:Start], { id: 1 })
    #   puts Trailblazer::Activity::Present.tree(stack) # renders the trail.
    #
    # Hooks into the TaskWrap.
    module Trace
      # {:argumenter} API
      # FIXME: needs Introspect.arguments_for_call
      # FIXME: needs TaskWrap.arguments_for_call
      def self.arguments_for_call(activity, (options, flow_options), **circuit_options)
        tracing_flow_options = {
          stack:         Trace::Stack.new,
        }

        tracing_circuit_options = {
          wrap_runtime:  ::Hash.new(Trace.wirings), # FIXME: this still overrides existing :wrap_runtime.
        }

        return activity, [ options, flow_options.merge(tracing_flow_options) ], circuit_options.merge(tracing_circuit_options)
      end

      def self.call(activity, (options, flow_options), *args)
        activity, (options, flow_options), circuit_options = Trace.arguments_for_call( activity, [options, flow_options], {} ) # only run once for the entire circuit!
        last_signal, (options, flow_options) =
          activity.(
            [options, flow_options],
            circuit_options.merge({ argumenter: [ Introspect.method(:arguments_for_call), TaskWrap.method(:arguments_for_call) ] })
          )

        return flow_options[:stack].to_a, last_signal, [options, flow_options]
      end

      private

      # Insertions for the trace tasks that capture the arguments just before calling the task,
      # and before the TaskWrap is finished.
      #
      # Note that the TaskWrap steps are implemented in Activity::TaskWrap::Trace.
      def self.wirings
        Module.new do
          extend Activity[ Activity::Path::Plan ]

          task TaskWrap::Trace.method(:capture_args),   id: "task_wrap.capture_args",   before: "task_wrap.call_task"
          task TaskWrap::Trace.method(:capture_return), id: "task_wrap.capture_return", before: "End.success", group: :end
        end
      end

      Entity = Struct.new(:task, :type, :value, :value2, :introspection)

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
