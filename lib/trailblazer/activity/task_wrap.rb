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
      # [:wrap_static] The taskWrap used for the topmost activity/operation.
      def invoke(activity, args, wrap_runtime: {}, wrap_static: initial_wrap_static, **circuit_options) # FIXME: why do we need this method?
        circuit_options = circuit_options.merge(
          runner:       TaskWrap::Runner,
          wrap_runtime: wrap_runtime,
          # This {:activity} structure is currently (?) only needed in {TaskWrap.wrap_static_for}, where we
          # access {activity[:wrap_static]} to compile the effective taskWrap.
          activity:     {wrap_static: {activity => wrap_static}, nodes: {}}, # for Runner. Ideally we'd have a list of all static_wraps here (even nested).
        )

        # signal, (ctx, flow), circuit_options =
        TaskWrap::Runner.(activity, args, **circuit_options)
      end

      # {:extension} API
      # Extend the static taskWrap from a macro or DSL call.
      # Gets executed in {Intermediate.call} which also provides {config}.

      def initial_wrap_static(*)
        # return initial_sequence
        TaskWrap::Pipeline.new([Pipeline::Row["task_wrap.call_task", TaskWrap.method(:call_task)]])
      end

      # Use this in your macros if you want to extend the {taskWrap}.
      def Extension(merge:)
        Extension.new(merge: Pipeline::Merge.new(*merge))
      end

      # Extension are used at compile-time with {wrap_static}, usually with the {dsl} gem.
      class Extension
        def self.Runtime(*inserts)
          merge = inserts.collect do |task, options|
            runtime_extension_for(task, **options)
          end

          Pipeline::Merge.new(*merge)
        end

        def self.runtime_extension_for(task, id:, prepend: "task_wrap.call_task", append: nil)
          insert, insert_id = append ? [:Append, append] : [:Prepend, prepend]

          {
            insert: [Activity::Adds::Insert.method(insert), insert_id],
            row:    TaskWrap::Pipeline::Row(id, task)
          }
        end

        def initialize(merge:)
          @merge = merge
        end

        # Compile-time:
        # Gets called via the {Normalizer} and represents an {:extensions} item.
        # Adds/alters the activity's {wrap_static}.
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
