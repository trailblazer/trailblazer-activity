module Trailblazer
  class Activity < Module
    module Trace
      class << self
        # Public entry point to activate tracing when running {activity}.
        def call(activity, (ctx, flow_options), circuit_options={})
          activity, (ctx, flow_options), circuit_options = Trace.arguments_for_call( activity, [ctx, flow_options], circuit_options ) # only run once for the entire circuit!

          signal, (ctx, flow_options) = Activity::TaskWrap.invoke(activity, [ctx, flow_options], circuit_options)

          return flow_options[:stack], signal, [ctx, flow_options]
        end

        alias_method :invoke, :call

        def arguments_for_call(activity, (options, flow_options), **circuit_options)
          tracing_flow_options = {
            stack: Trace::Stack.new,
          }

          tracing_circuit_options = {
            wrap_runtime:  ::Hash.new(Trace.merge_plan), # FIXME: this still overrides existing :wrap_runtime.
          }

          return activity, [ options, tracing_flow_options.merge(flow_options) ], circuit_options.merge(tracing_circuit_options)
        end
      end

      module_function
      # Insertions for the trace tasks that capture the arguments just before calling the task,
      # and before the TaskWrap is finished.
      #
      # Note that the TaskWrap steps are implemented in Activity::TaskWrap::Trace.
      #
      # @private
      def merge_plan
        TaskWrap::Pipeline::Merge.new(
          [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["task_wrap.capture_args",   Trace.method(:capture_args)]],
          [TaskWrap::Pipeline.method(:append),        nil,                   ["task_wrap.capture_return", Trace.method(:capture_return)]],
        )
      end

      # taskWrap step to capture incoming arguments of a step.
      def capture_args(wrap_config, original_args)
        original_args = capture_for(wrap_config[:task], *original_args)

        return wrap_config, original_args
      end

      # taskWrap step to capture outgoing arguments from a step.
      def capture_return(wrap_config, original_args)
        (original_options, original_flow_options, _) = original_args[0]

        original_flow_options[:stack] << Entity::Output.new(
          wrap_config[:task], {}, wrap_config[:return_signal]
        ).freeze

        original_flow_options[:stack].unindent!


        return wrap_config, original_args
      end

      # It's important to understand that {flow[:stack]} is mutated by design. This is needed so
      # in case of exceptions we still have a "global" trace - unfortunately Ruby doesn't allow
      # us a better way.
      def capture_for(task, (ctx, flow), activity:, **circuit_options)
        flow[:stack].indent!

        flow[:stack] << Entity::Input.new(
          task, activity, [ctx, ctx.inspect]
        ).freeze

        return [ctx, flow], circuit_options.merge(activity: activity)
      end

      # Structures used in {capture_args} and {capture_return}.
      # These get pushed onto one {Level} in a {Stack}.
      #
      #   Level[
      #     Level[              ==> this is a scalar task
      #       Entity::Input
      #       Entity::Output
      #     ]
      #     Level[              ==> nested task
      #       Entity::Input
      #       Level[
      #         Entity::Input
      #         Entity::Output
      #       ]
      #       Entity::Output
      #     ]
      #   ]
      Entity         = Struct.new(:task, :activity, :data)
      Entity::Input  = Class.new(Entity)
      Entity::Output = Class.new(Entity)

      class Level < Array
        def inspect
          %{<Level>#{super}}
        end

        # @param level {Trace::Level}
        def self.input_output_nested_for_level(level)
          input  = level[0]
          output = level[-1]

          output, nested = output.is_a?(Entity::Output) ? [output, level-[input, output]] : [nil, level[1..-1]]

          return input, output, nested
        end
      end

      # Mutable/stateful per design. We want a (global) stack!
      class Stack
        def initialize
          @nested  = Level.new
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
