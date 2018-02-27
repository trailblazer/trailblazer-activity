module Trailblazer
  module Activity::Schema
    #  the list of what tasks to add to the graph, for the "drawer"
    # produces immutable list of: (node, magnetic_to (incoming colors), outgoing colors)
    #  via #to_a

    #mutable, for DSL
    #
    # @api private
    class Sequence < ::Array
      Element = Struct.new(:id, :configuration)

      # Insert the task into {Sequence} array by respecting options such as `:before`.
      # This mutates the object per design.
      #
      # @param wiring [ [:success, :special_1], A, [ Output, Output ] ]
      def add(id, wiring, before:nil, after:nil, replace:nil, delete:nil)
        element = Element.new(id, wiring).freeze

        return insert(find_index!(before),  element) if before
        return insert(find_index!(after)+1, element) if after
        return self[find_index!(replace)] = element  if replace
        return delete_at(find_index!(delete))        if delete

        self << element
      end

      def to_a
        collect { |element| element.configuration }
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
