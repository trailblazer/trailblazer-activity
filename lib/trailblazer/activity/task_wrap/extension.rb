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
      def self.Extension(*inserts)
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
          @extension_rows = extension_rows # those rows are simple ADDS instructions.
        end

        # Merges {extension_rows} into the {Pipeline} instance.
        # This is usually used in step extensions or at runtime for {wrap_runtime}.
        def call(task_wrap_pipeline, **)
          Adds.apply_adds(task_wrap_pipeline, @extension_rows)
        end

        # Create extensions from the friendly interface that can alter the wrap_static
        # of a step in an activity. The returned extensionn can be passed directly via {:extensions}
        # to the compiler, or when using the `#step` DSL.
        def self.WrapStatic(*inserts)
          Activity::Deprecate.warn caller_locations[0], "Using `TaskWrap::Extension.WrapStatic()` is deprecated. Please use `TaskWrap.Extension()`."

          # FIXME: change or deprecate.
          TaskWrap.Extension(*inserts)
        end
      end # Extension
    end # TaskWrap
  end
end
