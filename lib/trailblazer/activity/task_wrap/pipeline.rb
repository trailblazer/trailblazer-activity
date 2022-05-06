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

      # attr_reader :sequence

      def self.insert_before(pipe, before_id, insertion)
        raise
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
        index = pipe.sequence.find_index { |(seq_id, _)| seq_id == id }
      end

      class Row < Array
        def id
          self[0]
        end
      end

      # Functions to mutate the Sequence/Pipeline by inserting, replacing, or deleting a row.
      # These functions are called in {apply_adds => insert_row}.
      #
      # they don't mutate the data structure but rebuild it, has to respond to {to_a}
      #
      # DISCUSS: those methods shouldn't mutate, as we would alter the taskWrap at runtime
      # when using {:wrap_runtime}.
      # DISCUSS: these methods shouldn't even be called directly but via the ADDS interface.
      module Insert
        module_function

        # Append {new_row} after {insert_id}.
        def Append(pipeline, new_rows, insert_id) # TODO: do we need append without ID?
          index, ary = find(pipeline, insert_id)

          return build(pipeline, ary[0..index] + new_rows + ary[index+1..-1])
        end

        # Insert {new_rows} before {insert_id}.
        def Prepend(pipeline, new_rows, insert_id) # DISCUSS: do we really want multiple rows? We barely need it.
          index, ary = find(pipeline, insert_id)

          return build(pipeline, new_rows + ary) if index == 0
          return build(pipeline, ary[0..index-1] + new_rows + ary[index..-1])
        end

        def Replace(sequence, new_rows, insert_id)
          index, sequence = find(sequence, insert_id)

          sequence[index], _ = *new_rows # TODO: replace and insert remaining, if any.
          sequence
        end

        def Delete(sequence, _, insert_id)
          index, sequence = find(sequence, insert_id)

          sequence.delete(sequence[index])
          sequence
        end

        def build(sequence, rows)
          sequence.class.new(rows)
        end

        # @private
        def find_index(ary, insert_id)
          ary.find_index { |row| row.id == insert_id }
        end

        def find(sequence, insert_id)
          ary = sequence.to_a

          index = find_index(ary, insert_id) or raise #Sequence::IndexError.new(sequence, insert_id)

          return index, ary
        end
      end

      # TODO: move me somewhere nice!
      # "one" ADDS structure: {row: ..., insert: [Insert, "id"]}
      module Adds
        module_function
        # @returns Sequence New sequence instance
        # @private
        def insert_row(sequence, row:, insert:)
          insert_function, *args = insert

          insert_function.(sequence, [row], *args)
        end

        # TODO: make this the only public method of Sequence.
        # Inserts one or more {Add} into {sequence}.
        def apply_adds(sequence, adds)

          adds.each do |add|
            sequence = insert_row(sequence, **add)
          end

          sequence
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
