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

      # Helper for normalizers.
      def self.prepend(pipe, insertion_id, insertion, replace: 0) # FIXME: {:replace}
        adds =
          insertion.collect do |id, task|
            {insert: [Adds::Insert.method(:Prepend), insertion_id], row: Pipeline.Row(id, task)}
          end

        Adds.apply_adds(pipe, adds)
      end

      # TODO: remove me when old tW extension API is deprecated.
      def self.method(name)
        new_name = {
          insert_before: :Prepend,
          insert_after: :Append,
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
    end
  end
end
