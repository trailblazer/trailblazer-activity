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
      #
      # inserts must be [ [task, id: ..., append: "task_wrap.call_task"] ]
      def Extension(*inserts, merge: nil)
        if merge
          return Extension::WrapStatic.new(extension: Extension.new(*merge))
        # TODO: deprecate me! or remove?
        end

        Extension.build(*inserts)
      end

      # An {Extension} is a collection of steps to be inserted into a taskWrap.
      # It gets called either at
      #   * compile-time and adds its steps to the wrap_static (see Extension::WrapStatic)
      #   * run-time in {TaskWrap::Runner} and adds its steps dynamically at runtime to the
      #     step's taskWrap
      class Extension
        # Build a taskWrap extension from the friendly API {[task, id:, ...]}
        def self.build(*inserts)
          extension_rows = inserts.collect do |task, options|
            extension_step_for(task, **options)
          end

          new(*extension_rows)
        end

        def self.extension_step_for(task, id:, prepend: "task_wrap.call_task", append: nil)
          insert, insert_id = append ? [:Append, append] : [:Prepend, prepend]

          {
            insert: [Activity::Adds::Insert.method(insert), insert_id],
            row:    TaskWrap::Pipeline::Row(id, task)
          }
        end

        def initialize(*extension_rows)
          extension_rows = deprecated_extension_for(extension_rows) # TODO: remove me soon!

          @extension_rows = extension_rows # those rows are simple ADDS instructions.
        end

        # Merges {extension_rows} into the {Pipeline} instance.
        # This is usually used in step extensions or at runtime for {wrap_runtime}.
        def call(task_wrap_pipeline)
          Adds.apply_adds(task_wrap_pipeline, @extension_rows)
        end

        # TODO: remove me at some point.
        def deprecated_extension_for(extension_rows)
          return extension_rows unless extension_rows.find { |ext| ext.is_a?(Array) }

          warn "[Trailblazer] You are using the old API for taskWrap extensions.
Please update to the new TaskWrap.Extension() API: # FIXME !!!!!"

          extension_rows.collect do |ary|
            {
              insert: ary[0..1],
              row: Pipeline.Row(*ary[2])
            }
          end
        end

        # Extension are used at compile-time with {wrap_static}, usually with the {dsl} gem.
        class WrapStatic
          def initialize(extension:)
            @extension = extension
          end

          # Compile-time:
          # Gets called via the {Normalizer} and represents an {:extensions} item.
          # Adds/alters the activity's {wrap_static}.
          def call(config:, task:, **)
            before_pipe = State::Config.get(config, :wrap_static, task.circuit_task)

            State::Config.set(config, :wrap_static, task.circuit_task, @extension.(before_pipe))
          end
        end # WrapStatic
      end # Extension
    end # TaskWrap
  end
end
require "trailblazer/activity/task_wrap/pipeline"
require "trailblazer/activity/task_wrap/call_task"
require "trailblazer/activity/task_wrap/runner"
require "trailblazer/activity/task_wrap/variable_mapping"
