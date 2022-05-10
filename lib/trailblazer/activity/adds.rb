module Trailblazer
  class Activity

      # The Adds interface are mechanics to alter compile-time sequences/pipelines.
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
        end # Insert
      end
  end
end
