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
        def call(task_wrap_pipeline)
          Adds.apply_adds(task_wrap_pipeline, @extension_rows)
        end

        # Create extensions from the friendly interface that can alter the wrap_static
        # of a step in an activity. The returned extensionn can be passed directly via {:extensions}
        # to the compiler, or when using the `#step` DSL.
        def self.WrapStatic(*inserts)
          WrapStatic.new(extension: TaskWrap.Extension(*inserts))
        end

        # Extension are used at compile-time with {wrap_static}, mostly with the {dsl} gem.
        # At compile-time, {WrapStatic} extensions are compiled in {Sequence::Compiler}.
        #
        # Each extension alters the activity's wrap_static taskWrap.
        # {WrapStatic#call} returns the new "config" object with an updated config[:wrap_static] field.
        class WrapStatic
          def initialize(extension:)
            @extension = extension
          end

          # DISCUSS: `wrap_static[task]` is too implicit, we're returning the default tw here set via Hash.new(). the initial tw should probably be generated explicitly via the DSL?
          def call(config:, task:, **)
            wrap_static = config[:wrap_static]  # The activity's data structure keeping a map of {task => task_wrap}. This will be
                                                # merged into {config}
            task_wrap   = wrap_static[task]     # the "actual" taskWrap for {task}. Your steps will be added to that.

            # Execute the extension, which adds steps to the tw.
            new_task_wrap = @extension.(task_wrap)

            # Overwrite the original task_wrap:
            wrap_static = wrap_static.merge(task => new_task_wrap)

            # DISCUSS: does it make sense to test the immutable behavior here? What would be the worst outcome?
            config.merge(wrap_static: wrap_static) # Return new config hash. This needs to be immutable code!
          end
        end # WrapStatic
      end # Extension
    end # TaskWrap
  end
end
