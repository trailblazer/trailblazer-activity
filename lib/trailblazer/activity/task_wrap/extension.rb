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
      # inserts must be
      # An {Extension} can be used for {:wrap_runtime}. It expects a collection of
      # "friendly interface" arrays.
      #
      #   TaskWrap.Extension([ [task, id: "my_logger", append: "task_wrap.call_task"] ])
      #
      # If you want a {wrap_static} extension, wrap it using `Extension.WrapStatic.new`.
      def self.Extension(*inserts, merge: nil)
        if merge
          return Extension::WrapStatic.new(extension: Extension.new(*merge))
          # TODO: remove me once we drop the pre-friendly interface.
        end

        Extension.build(*inserts)
      end

      # An {Extension} is a collection of ADDS objects to be inserted into a taskWrap.
      # It gets called either at
      #   * compile-time and adds its steps to the wrap_static (see Extension::WrapStatic)
      #   * run-time in {TaskWrap::Runner} and adds its steps dynamically at runtime to the
      #     step's taskWrap
      class Extension
        # Build a taskWrap extension from the "friendly interface" {[task, id:, ...]}
        def self.build(*inserts)
          extension_rows = inserts.collect do |task, options|
            adds_for_friendly_interface(task, **options)
          end

          new(*extension_rows)
        end

        # Translate the friendly interface to ADDS.
        def self.adds_for_friendly_interface(task, id:, prepend: "task_wrap.call_task", append: nil)
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

        # TODO: remove me once we drop the pre-friendly interface.
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
