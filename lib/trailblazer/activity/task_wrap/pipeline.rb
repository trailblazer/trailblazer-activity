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

      attr_reader :sequence

      def self.insert_before(pipe, before_id, insertion)
        index = find_index(pipe, before_id)

        seq = pipe.sequence.dup

        Pipeline.new(seq.insert(index, insertion))
      end

      def self.insert_after(pipe, after_id, insertion)
        index = find_index(pipe, after_id)

        seq = pipe.sequence.dup

        Pipeline.new(seq.insert(index+1, insertion))
      end

      def self.append(pipe, _, insertion)
        Pipeline.new(pipe.sequence + [insertion])
      end

      def self.prepend(pipe, insertion_id, insertion, replace: 0)
        return Pipeline.new(insertion.to_a + pipe.sequence) if insertion_id.nil?

        index = find_index(pipe, insertion_id)

        Pipeline.new(pipe.sequence[0..index-1] + insertion.to_a + pipe.sequence[index+replace..-1])
      end

      # @private
      def self.find_index(pipe, id)
        _index = pipe.sequence.find_index { |(seq_id, _)| seq_id == id }
      end


      # Merges {extension_rows} into the {Pipeline} instance.
      # This is usually used in step extensions or at runtime for {wrap_runtime}.
      #
      # {Extension} API
      class Merge # TODO: RENAME TO TaskWrap::Extension(::Merge)
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
