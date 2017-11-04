# TODO: delete

class Trailblazer::Activity::Schema
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
        start: Sequence.new,
        main:  Sequence.new, # normal steps
        end:   Sequence.new, # ends
        unresolved:   Sequence.new, # div
      }

      @order = [ :start, :main, :end, :unresolved ]
      @id_to_group = { }
    end

    def add(id, seq_options, group: :main, **sequence_options)
      group = @groups[group] or raise "unknown group, implement me"

      # "upsert"
      # DISCUSS: move this to Sequence?
      if existing = group.send( :find_index, id) # FIXME
        arr = group[existing].instructions.dup

# raise seq_options.inspect

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
  end
end
