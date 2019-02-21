class Trailblazer::Activity
  module TaskWrap
    # DISCUSS: maybe a separate sequence and index map is faster?
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
    end
  end
end
