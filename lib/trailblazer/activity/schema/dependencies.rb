# TODO: delete

module Trailblazer
  class Activity::Schema
    module Magnetic
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

          # "upsert"
          if ( cfg = find(id) )
            group, index = cfg
            arr = group[index].instructions.dup

            arr[0] += seq_options[0] # merge the magnetic_to, only.
            arr[2] += seq_options[2] # merge the polarization

            group.add(id, arr, replace: id)
          else
            group.add(id, seq_options, **sequence_options) # handles
          end

        end

        # Produces something like
        #
        # (one line per node)
        #
        # [
        #   #  magnetic to
        #   #  color | signal|outputs
        #   [ [:success], A,  [R, L] ],
        #   [ [:failure], E, [L, e_to_success] ],
        #   [ [:success], B, [R, L] ],
        #   [ [:success], C, [R] ],

        #   [ [:success, :e_to_success], ES, [] ], # magnetic_to needs to have the special line, too.
        #   [ [:failure], EF, [] ],
        # ]
        def to_a
          @order.collect{ |name| @groups[name].to_a }.flatten(1)
        end

        private
        def find(id)
          @groups.find do |name, group|
            index = group.send( :find_index, id )
            return group, index if index
          end
        end
      end
    end # Magnetic
  end
end
