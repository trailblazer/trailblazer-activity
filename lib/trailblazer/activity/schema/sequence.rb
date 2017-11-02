module Trailblazer
  class Activity::Schema
    #  the list of what tasks to add to the graph, for the "drawer"
    # produces immutable list of: (node, magnetic_to (incoming colors), outgoing colors)
    #  via #to_a

    #mutable, for DSL
    #
    # @api private
    class Sequence < ::Array
      Element = Struct.new(:id, :instructions)

      # Insert the task into {Sequence} array by respecting options such as `:before`.
      # This mutates the object per design.
      # @param element_wiring ElementWiring Set of instructions for a specific element in an activity graph.
      def insert!(id, wiring, before:nil, after:nil, replace:nil, delete:nil)
        element = Element.new(id, wiring).freeze

        return insert(find_index!(before),  element) if before
        return insert(find_index!(after)+1, element) if after
        return self[find_index!(replace)] = element  if replace
        return delete_at(find_index!(delete))        if delete

        self << element
      end

      # return the "schema steps array" that is consumed by Schema.bla
      #
      # [ [:success], A,  [R, L] ],
      # [ [:failure], E, [] ],
      # [ [:success], B, [R, L] ],
      # [ [:success], C, [R, L] ],
      # [ [:failure], F, [L, Z] ],
      #   [ [:my_z], S, [] ], # "connect"


      # [ [:success], ES, [] ],
      # [ [:failure], EF, [] ],
      def to_a
        collect { |element| element.instructions }.flatten(1)
      end

      private

      def find_index(id)
        element = find { |el| el.id == id }
        index(element)
      end

      def find_index!(id)
        find_index(id) or raise IndexError.new(id)
      end

      class IndexError < IndexError; end
    end
  end
end
