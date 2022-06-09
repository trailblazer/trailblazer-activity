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
          def Append(pipeline, new_rows, insert_id=nil)
            index, ary =
              if insert_id
                find(pipeline, insert_id)
              else
                _ary = pipeline.to_a # FIXME: make it #apply_on_ary or something.
                [_ary.size, _ary]
              end

            return build(pipeline, ary[0..index] + new_rows + Array(ary[index+1..-1]))# DISCUSS: we need the last Array() because an empty array would break here (why, though?).
          end

          # Insert {new_rows} before {insert_id}.
          def Prepend(pipeline, new_rows, insert_id) # DISCUSS: do we really want multiple rows? We barely need it.
            index, ary = find(pipeline, insert_id)

            return build(pipeline, new_rows + ary) if index == 0
            return build(pipeline, ary[0..index-1] + new_rows + ary[index..-1])
          end

          def Replace(pipeline, new_rows, insert_id)
            index, ary = find(pipeline, insert_id)

            return build(pipeline, new_rows + ary[index+1..-1]) if index == 0
            return build(pipeline, ary[0..index-1] + new_rows + ary[index+1..-1])
          end

          def Delete(pipeline, _, insert_id)
            index, ary = find(pipeline, insert_id)

            return build(pipeline, ary[index+1..-1]) if index == 0
            return build(pipeline, ary[0..index-1] + ary[index+1..-1])
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

            index = find_index(ary, insert_id) or raise IndexError.new(sequence, insert_id)

            return index, ary
          end
        end # Insert

        class IndexError < ::IndexError
          def initialize(sequence, step_id)
            valid_ids = sequence.to_a.collect{ |row| row.id.inspect }

            message = "\n" \
              "\e[31m#{step_id.inspect} is not a valid step ID. Did you mean any of these ?\e[0m\n" \
              "\e[32m#{valid_ids.join("\n")}\e[0m"

            super(message)
          end
        end
      end
  end
end
