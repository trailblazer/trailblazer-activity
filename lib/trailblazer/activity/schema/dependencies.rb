module Trailblazer
  module Activity::Schema
    # Helps organizing the structure of the circuit and allows to define steps that
    # might be inserted in a completely different order, but it's experimental.
    #
    # Translates linear DSL calls that might refer to the same task several times into a linear "drawing instruction"
    # that can be consumed by Schema.bla.
    #
    # This class is experimental.
    class Dependencies
      def initialize
        @groups  = {
          start:      Sequence.new,
          main:       Sequence.new, # normal steps
          end:        Sequence.new, # ends
          unresolved: Sequence.new, # div
        }

        @order = [ :start, :main, :end, :unresolved ]
      end

      def add(id, seq_options, group: :main, **sequence_options)
        group = @groups[group] or raise "unknown group #{group}, implement me"

        group.add(id, seq_options, **sequence_options) # handles
      end

      def to_a
        @order.collect{ |name| @groups[name].to_a }.flatten(1)
      end

      # private
      def find(id)
        @groups.find do |name, group|
          index = group.send( :find_index, id )
          return group, index if index
        end
      end
    end
  end
end


# Activity.build do
#   step :extract,  failure: End("End.validate.extract_failed")
#   step :validate
# end
