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
      def invoke(activity, args, wrap_runtime: {}, **circuit_options)
        circuit_options = circuit_options.merge(
          runner:       TaskWrap::Runner,
          wrap_runtime: wrap_runtime,
          activity:     {wrap_static: {activity => initial_wrap_static}, nodes: {}}, # for Runner. Ideally we'd have a list of all static_wraps here (even nested).
        )

        # signal, (ctx, flow), circuit_options =
        Runner.(activity, args, **circuit_options)
      end

      # {:extension} API
      # Extend the static taskWrap from a macro or DSL call.
      # Gets executed in {Intermediate.call} which also provides {config}.

      def initial_wrap_static(*)
        # return initial_sequence
        TaskWrap::Pipeline.new([["task_wrap.call_task", TaskWrap.method(:call_task)]])
      end

      # Use this in your macros if you want to extend the {taskWrap}.
      def Extension(merge:)
        Extension.new(merge: Pipeline::Merge.new(*merge))
      end

      class Extension
        def initialize(merge:)
          @merge = merge
        end

        def call(config:, task:, **)
          before_pipe = State::Config.get(config, :wrap_static, task.circuit_task)

          State::Config.set(config, :wrap_static, task.circuit_task, @merge.(before_pipe))
        end
      end
    end # TaskWrap
  end
end
require "trailblazer/activity/task_wrap/pipeline"
require "trailblazer/activity/task_wrap/call_task"
require "trailblazer/activity/task_wrap/runner"
require "trailblazer/activity/task_wrap/variable_mapping"
require "trailblazer/activity/task_wrap/inject"
