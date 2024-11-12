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
      #   TaskWrap.Extension([task, id: "my_logger", append: "task_wrap.call_task"], [...])
      #
      # If you want a {wrap_static} extension, wrap it using `Extension.WrapStatic.new`.
      def self.Extension(*inserts, merge: nil)
        if merge
          Deprecate.warn caller_locations[0], "The :merge option for TaskWrap.Extension is deprecated and will be removed in 0.16.
Please refer to https://trailblazer.to/2.1/docs/activity.html#activity-taskwrap-static and have a great day."

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
          # For performance reasons we're computing the ADDS here and not in {#call}.
          extension_rows = Activity::Adds::FriendlyInterface.adds_for(inserts)

          new(*extension_rows)
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

          Deprecate.warn caller_locations[3], "You are using the old API for taskWrap extensions.
Please update to the new TaskWrap.Extension() API."

          extension_rows.collect do |ary|
            {
              insert: ary[0..1],
              row: Pipeline.Row(*ary[2])
            }
          end
        end

        # Create extensions from the friendly interface that can alter the wrap_static
        # of a step in an activity. The returned extensionn can be passed directly via {:extensions}
        # to the compiler, or when using the `#step` DSL.
        def self.WrapStatic(*inserts)
          WrapStatic.new(extension: TaskWrap.Extension(*inserts))
        end

        # Extension are used at compile-time with {wrap_static}, mostly with the {dsl} gem.
        # {WrapStatic} extensions are called for setup through {Intermediate.config} at compile-time.
        # Each extension alters the activity's wrap_static taskWrap.
        class WrapStatic
          def initialize(extension:)
            @extension = extension
          end

          def call(config:, task:, **)
            # Add the extension's task(s) to the activity's {:wrap_static} taskWrap
            # which is stored in the {:config} field.
            wrap_static = config[:wrap_static]                 # the activity's {wrap_static}.
            task_wrap   = wrap_static[task] # the "original" taskWrap for {task}.

            # Overwrite the original task_wrap:
            wrap_static = wrap_static.merge(task => @extension.(task_wrap))

            # DISCUSS: does it make sense to test the immutable behavior here? What would be the worst outcome?
            config.merge(wrap_static: wrap_static) # Return new config hash. This needs to be immutable code!
          end
        end # WrapStatic
      end # Extension
    end # TaskWrap
  end
end
