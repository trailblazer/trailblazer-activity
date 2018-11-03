module Trailblazer
  class Activity < Module # Trace#call will call the activities and trace what steps are called, options passed,
    # and the order and nesting.
    #
    #   stack, _ = Trailblazer::Activity::Trace.(activity, [{ id: 1 }, {}])
    #   puts Trailblazer::Activity::Trace::Present.(stack) # renders the trail.
    #
    # Hooks into the taskWrap.
    module Trace
      class << self
        # {:argumenter} API
        # FIXME: needs Introspect.arguments_for_call
        # FIXME: needs TaskWrap.arguments_for_call
        def arguments_for_call(activity, (options, flow_options), **circuit_options)
          tracing_flow_options = {
            stack:         Trace::Stack.new,
          }

          tracing_circuit_options = {
            wrap_runtime:  ::Hash.new(Trace.wirings), # FIXME: this still overrides existing :wrap_runtime.
          }

          return activity, [ options, tracing_flow_options.merge(flow_options) ], circuit_options.merge(tracing_circuit_options)
        end

        def call(activity, (options, flow_options), circuit_options={})
          activity, (options, flow_options), circuit_options = Trace.arguments_for_call( activity, [options, flow_options], circuit_options ) # only run once for the entire circuit!

          last_signal, (options, flow_options) =
            Activity::TaskWrap.invoke(activity, [options, flow_options], circuit_options)

          return flow_options[:stack], last_signal, [options, flow_options]
        end

        alias_method :invoke, :call

        # Insertions for the trace tasks that capture the arguments just before calling the task,
        # and before the TaskWrap is finished.
        #
        # Note that the TaskWrap steps are implemented in Activity::TaskWrap::Trace.
        #
        # @private
        def wirings
          Module.new do
            extend Activity::Path::Plan()

            task TaskWrap::Trace.method(:capture_args),   id: "task_wrap.capture_args",   before: "task_wrap.call_task"
            task TaskWrap::Trace.method(:capture_return), id: "task_wrap.capture_return", before: "End.success", group: :end
          end
        end
      end

      Entity = Struct.new(:task, :activity, :data)
      class Entity::Input < Entity
      end

      class Entity::Output < Entity
      end

      class Level < Array
        def inspect
          %{<Level>#{super}}
        end
      end

      # Mutable/stateful per design. We want a (global) stack!
      class Stack
        def initialize
          @nested  = []
          @stack   = [ @nested ]
        end

        def indent!
          current << indented = Level.new
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
