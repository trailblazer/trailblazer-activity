module Trailblazer
  class Activity
    # Developer's docs: https://trailblazer.to/2.1/docs/internals#internals-wiring-api-adds-interface
    #
    # The Adds interface are mechanics to alter sequences/pipelines.
    # "one" ADDS structure: {row: ..., insert: [Insert, "id"]}
    #
    # To work with the instructions provided here, the pipeline structure
    # needs to expose {#to_a}.
    module Adds
      module_function

      # DISCUSS: Canonical entry point for pipeline altering?
      def call(pipeline, *inserts)
        instructions = FriendlyInterface.adds_for(inserts)

        Adds.apply_adds(pipeline, instructions)
      end

      # @returns Sequence/Pipeline New sequence instance
      # @private
      def insert_row(pipeline, row:, insert:)
        insert_function, *args = insert

        insert_function.(pipeline, row, *args)
      end

      # Inserts one or more {Adds} into {pipeline}.
      def apply_adds(pipeline, adds)
        adds.each do |add|
          pipeline = insert_row(pipeline, **add)
        end

        pipeline
      end

      module FriendlyInterface
        # @public
        # @return Array of ADDS
        #
        # Translate a collection of friendly interface to ADDS.
        # This is a mini-DSL, if you want.
        def self.adds_for(inserts)
          inserts.collect do |task, options|
            build_adds(task, **options)
          end
        end

        # @private
        def self.build_adds(task, **options)
          row, options = build_row_for(task, **options)

          action, insert_id = options.to_a.first # DISCUSS: maybe we can find another way to extract the DSL "insertion action" option.

          insert = OPTION_TO_METHOD.fetch(action)

          {
            insert: [insert, insert_id],
            row:    row
          }
        end

        def self.build_row_for(task, row: nil, **options)
          return row, options if row

          return build_row(task, **options)
        end

        def self.build_row(task, id:, **options)
          return TaskWrap::Pipeline.Row(id, task), options
        end
      end

      # Functions to alter the Sequence/Pipeline by inserting, replacing, or deleting a row.
      #
      # they don't mutate the data structure but rebuild it, has to respond to {to_a}
      #
      # These methods are invoked via {Adds.apply_adds} and should never be called directly.
      module Insert
        module_function

        # Append {new_row} after {insert_id}.
        def Append(pipeline, new_row, insert_id = nil)
          build_from_ary(pipeline, insert_id) do |ary, index|
            index = ary.size if index.nil? # append to end of pipeline.

            range_before_index(ary, index + 1) + [new_row] + Array(ary[index + 1..-1])
          end
        end

        # Insert {new_row} before {insert_id}.
        def Prepend(pipeline, new_row, insert_id = nil)
          build_from_ary(pipeline, insert_id) do |ary, index|
            index = 0 if index.nil? # Prepend to beginning of pipeline.

            range_before_index(ary, index) + [new_row] + ary[index..-1]
          end
        end

        def Replace(pipeline, new_row, insert_id)
          build_from_ary(pipeline, insert_id) do |ary, index|
            range_before_index(ary, index) + [new_row] + ary[index + 1..-1]
          end
        end

        def Delete(pipeline, _, insert_id)
          build_from_ary(pipeline, insert_id) do |ary, index|
            range_before_index(ary, index) + ary[index + 1..-1]
          end
        end

        # @private
        def build(sequence, rows)
          sequence.class.new(rows)
        end

        # @private
        def find_index(ary, insert_id)
          ary.find_index { |row| row.id == insert_id }
        end

        # Converts the pipeline structure to an array,
        # automatically finds the index for {insert_id},
        # and calls the user block with the computed values.
        #
        # Single-entry point, could be named {#call}.
        # @private
        def apply_on_ary(pipeline, insert_id, raise_index_error: true, &block)
          ary = pipeline.to_a

          if insert_id.nil?
            index = nil
          else
            index = find_index(ary, insert_id) # DISCUSS: this only makes sense if there are more than {Append} using this.
            raise IndexError.new(pipeline, insert_id) if index.nil? && raise_index_error
          end

          _new_ary = yield(ary, index) # call the block.
        end

        def build_from_ary(pipeline, insert_id, &block)
          new_ary = apply_on_ary(pipeline, insert_id, &block)

          # Wrap the sequence/pipeline array into a concrete Sequence/Pipeline.
          build(pipeline, new_ary)
        end

        # Always returns a valid, concat-able array for all indices
        # before the {index}.
        # @private
        def range_before_index(ary, index)
          return [] if index == 0
          ary[0..index - 1]
        end
      end # Insert

      OPTION_TO_METHOD = {
        prepend: Insert.method(:Prepend),
        append: Insert.method(:Append),
        replace: Insert.method(:Replace),
        delete: Insert.method(:Delete),
      }

      class IndexError < ::IndexError
        def initialize(sequence, step_id)
          valid_ids = sequence.to_a.collect { |row| row.id.inspect }

          message = "\n" \
            "\e[31m#{step_id.inspect} is not a valid step ID. Did you mean any of these ?\e[0m\n" \
            "\e[32m#{valid_ids.join("\n")}\e[0m"

          super(message)
        end
      end
    end
  end
end
