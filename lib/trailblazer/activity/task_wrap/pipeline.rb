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

      # Merges {extension_rows} into the {Pipeline} instance.
      # This is usually used in step extensions or at runtime for {wrap_runtime}.
      #
      # {Extension} API
      #
      # DISCUSS: why are we not using the ADDS interface here?
      class Merge # TODO: RENAME TO TaskWrap::Extension(::Merge)
        def initialize(*extension_rows)
          @extension_rows = extension_rows
        end

        def call(task_wrap_pipeline)
          # TODO: allow old API.
          Adds.apply_adds(task_wrap_pipeline, @extension_rows)
        end
      end
    end
  end
end
