class Trailblazer::Activity
  module TaskWrap
    # This "circuit" is optimized for
    #   a) merging speed at run-time, since features like tracing will be applied here.
    #   b) execution speed. Every task in the real circuit is wrapped with one of us.
    #
    # It doesn't come with built-in insertion mechanics (except for {Pipeline.prepend}).
    # Please add/remove steps using the {Activity::Adds} methods.
    class Pipeline
      def initialize(sequence)
        @sequence = sequence # [[id, task], ..]
      end

      # Execute the pipeline and call all its steps, passing around the {wrap_ctx}.
      def call(wrap_ctx, original_args)
        @sequence.each { |(_id, task)| wrap_ctx, original_args = task.(wrap_ctx, original_args) }

        return wrap_ctx, original_args
      end

      # Comply with the Adds interface.
      def to_a
        @sequence
      end

      # TODO: remove me when old tW extension API is deprecated.
      def self.method(name)
        new_name = {
          insert_before: :Prepend,
          insert_after: :Append,
          append: :Append,
          prepend: :Prepend,
        }.fetch(name)

        warn "[Trailblazer] Using `Trailblazer::Activity::TaskWrap::Pipeline.method(:#{name})` is deprecated.
Please use the new API: #FIXME!!!"

        Trailblazer::Activity::Adds::Insert.method(new_name)
      end

      def self.Row(id, task)
        Row[id, task]
      end

      class Row < Array
        def id
          self[0]
        end
      end

      # TODO: remove {Merge} when old tW extension API is deprecated.
      class Merge
        def self.new(*inserts)
          warn "[Trailblazer] Using `Trailblazer::Activity::TaskWrap::Pipeline::Merge.new` is deprecated.
Please use the new TaskWrap.Extension() API: #FIXME!!!"

          # We can safely assume that users calling {Merge.new} are using the old tW extension API, not
          # the "friendly API". That's why we don't go through {Extension.build}.
          TaskWrap::Extension.new(*inserts)
        end
      end # Merge

      # Implements adapter for a callable in a Pipeline.
      class TaskAdapter < Circuit::TaskAdapter
        # Returns a {Pipeline::TaskAdapter} instance that can be used directly in a Pipeline.
        # When `call`ed, it returns a Pipeline-interface return set.
        #
        # @see Circuit::TaskAdapter.for_step
        def self.for_step(callable, **)
          circuit_step = Circuit.Step(callable, option: false) # Since we don't have {:exec_context} in Pipeline, Option doesn't make much sense.

          TaskAdapter.new(circuit_step) # return a {Pipeline::TaskAdapter}
        end

        def call(wrap_ctx, args)
          _result, _new_wrap_ctx = @circuit_step.([wrap_ctx, args]) # For funny reasons, the Circuit::Step's call interface is compatible to the Pipeline's.

          # DISCUSS: we're mutating wrap_ctx, that's the whole point of this abstraction (plus kwargs).

          return wrap_ctx, args
        end
      end # TaskAdapter
    end
  end
end
