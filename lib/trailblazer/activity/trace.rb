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
          stack:         Trace::Stack.new,
        }

        tracing_circuit_options = {
          runner:        Wrap::Runner,
          wrap_runtime:  ::Hash.new(Trace.wirings), # FIXME: this still overrides existing wrap_runtimes.
          wrap_static:   ::Hash.new( Trailblazer::Activity::Wrap.initial_activity ), # FIXME
          introspection: compute_debug(activity), # FIXME: this is still also set in Activity::call
        }

        last_signal, (options, flow_options) = call_activity( activity, [
          options,
          # tracing_flow_options.merge(flow_options),
          tracing_flow_options,
        ], tracing_circuit_options, &block )

        return flow_options[:stack].to_a, last_signal, options, flow_options
      end

      private

      # TODO: test alterations with any wrap_circuit.
      def self.call_activity(activity, *args, &block)
        return activity.(*args) unless block
        block.(activity, *args)
      end

      # TODO: this is experimental.
      # Go through all nested Activities and grab their `Activity.debug` field. This gets all merged into
      # one big debugging hash, instead of computing it overly complex at runtime and while executing the circuit.
      def self.compute_debug(activity)
        arrs = Introspect.collect( activity, recursive: true ) { |task, _| task }.find_all { |task| task.is_a?(Interface) }.collect { |task| task.debug }.flatten(1)

        arrs.inject( activity.debug ) { |memo, debug| memo.merge(debug) }
      end

      # Insertions for the trace tasks that capture the arguments just before calling the task,
      # and before the TaskWrap is finished.
      #
      # Note that the TaskWrap steps are implemented in Activity::Wrap::Trace.
      def self.wirings
        Activity::Magnetic::Builder::Path.plan do
          task Wrap::Trace.method(:capture_args),   id: "task_wrap.capture_args",   before: "task_wrap.call_task"
          task Wrap::Trace.method(:capture_return), id: "task_wrap.capture_return", before: "End.success", group: :end
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
