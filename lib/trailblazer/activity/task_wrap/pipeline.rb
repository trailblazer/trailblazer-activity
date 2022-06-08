class Trailblazer::Activity
  module TaskWrap
    # This "circuit" is optimized for
    #   a) merging speed at run-time, since features like tracing will be applied here.
    #   b) execution speed. Every task in the real circuit is wrapped with one of us.
    class Pipeline
      def initialize(sequence)
        @sequence = sequence # [[id, task], ..]
      end

      def call(wrap_ctx, original_args)
        @sequence.each { |(_id, task)| wrap_ctx, original_args = task.(wrap_ctx, original_args) }

        return wrap_ctx, original_args
      end

      def to_a
        @sequence
      end

      # TODO: remove me when old API is deprecated.
      def self.method(name)
        new_name = {
          insert_before: :Prepend,
          insert_after: :Append,
        }.fetch(name)

        warn "[Trailblazer] Using `Trailblazer::Activity::TaskWrap::Pipeline.method(:#{name})` is deprecated.
Please use the new API: #FIXME!!!"

        Trailblazer::Activity::Adds::Insert.method(new_name)
      end

      # Helper for normalizers.
      def self.prepend(pipe, insertion_id, insertion, replace: 0) # FIXME: {:replace}
        adds =
          insertion.collect do |id, task|
            {insert: [Adds::Insert.method(:Prepend), insertion_id], row: Pipeline::Row(id, task)}
          end

        Adds.apply_adds(pipe, adds)
      end

      def self.Row(id, task) # TODO: test me.
        Row[id, task]
      end

      class Row < Array
        def id
          self[0]
        end
      end

      # FIXME: deprecate {Merge}

    end
  end
end
