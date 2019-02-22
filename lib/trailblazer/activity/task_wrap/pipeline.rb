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
        @sequence.each { |(id, task)| wrap_ctx, original_args = task.(wrap_ctx, original_args) }

        return wrap_ctx, original_args
      end

      attr_reader :sequence

      def self.insert_before(pipe, before_id, insertion)
        index = pipe.sequence.find_index { |(id, _)| id == before_id }

        seq = pipe.sequence.dup

        Pipeline.new(seq.insert(index, insertion))
      end

      def self.insert_after(pipe, after_id, insertion)
        index = pipe.sequence.find_index { |(id, _)| id == after_id }

        seq = pipe.sequence.dup

        Pipeline.new(seq.insert(index+1, insertion))
      end

      def self.append(pipe, _, insertion) # TODO: test me.
        Pipeline.new(pipe.sequence + [insertion])
      end

      # Merges {extension_rows} into the {task_wrap_pipeline}.
      # This is usually used in step extensions or at runtime for {wrap_runtime}.
      class Merge
        def initialize(*extension_rows)
          @extension_rows = extension_rows
        end

        def call(task_wrap_pipeline)
          @extension_rows.collect { |(insert_function, target_id, row)| task_wrap_pipeline = insert_function.(task_wrap_pipeline, target_id, row) }
          task_wrap_pipeline
        end
      end
    end
  end
end
