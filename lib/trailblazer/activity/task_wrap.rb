module Trailblazer
  class Activity
    #
    # Example with tracing:
    #
    # Call the task_wrap circuit:
    #   |-- Start
    #   |-- Trace.capture_args   [optional]
    #   |-- Call (call actual task) id: "task_wrap.call_task"
    #   |-- Trace.capture_return [optional]
    #   |-- Wrap::End
    module TaskWrap
      module_function

      # Compute runtime arguments necessary to execute a taskWrap per task of the activity.
      # This method is the top-level entry, called only once for the entire activity graph.
      # [:container_activity] the top-most "activity". This only has to look like an Activity
      #   and exposes a #[] interface so [:wrap_static] can be read and it's compatible to {Trace}.
      #   It is the virtual activity that "hosts" the actual {activity}.
      def invoke(activity, args, wrap_runtime: {}, container_activity: container_activity_for(activity), **circuit_options)
        circuit_options = circuit_options.merge(
          runner:       TaskWrap::Runner,
          wrap_runtime: wrap_runtime,
          activity:     container_activity # for Runner. Ideally we'd have a list of all static_wraps here (even nested).
        )

        # signal, (ctx, flow), circuit_options =
        TaskWrap::Runner.(activity, args, **circuit_options)
      end

      # {:extension} API
      # Extend the static taskWrap from a macro or DSL call.
      # Gets executed in {Intermediate.call} which also provides {config}.
      def initial_wrap_static
        INITIAL_WRAP_STATIC
      end

      # This is the top-most "activity" that hosts the actual activity being run.
      # The data structure is used in {TaskWrap.wrap_static_for}, where we
      # access {activity[:wrap_static]} to compile the effective taskWrap.
      #
      # It's also needed in Trace/Introspect and mimicks the host containing the actual activity.
      #
      # DISCUSS: we could cache that on Strategy/Operation level.
      #          merging the **config hash is 1/4 slower than before.
      def container_activity_for(activity, wrap_static: initial_wrap_static, id: nil, **config)
        {
          config: {
            wrap_static: {activity => wrap_static},
            **config
          },
          nodes:  Schema.Nodes([[id, activity]])
        }
      end

      INITIAL_WRAP_STATIC = Pipeline.new([Pipeline.Row("task_wrap.call_task", TaskWrap.method(:call_task))].freeze)
    end # TaskWrap
  end
end
