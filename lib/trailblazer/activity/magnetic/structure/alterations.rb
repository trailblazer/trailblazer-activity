module Trailblazer
  module Activity::Magnetic
    module DSL
      # works on a generic Dependencies structure that has no knowledge of magnetism.
      class Alterations
        def initialize
          @groups = Activity::Schema::Dependencies.new
          @future_magnetic_to = {} # DISCUSS: future - should it be here?
        end

        def add(id, options, **sequence_options)
          @groups.add(id, options, **sequence_options)

          # DISCUSS: future - should it be here?
          if magnetic_to = @future_magnetic_to.delete(id)
            magnetic_to( id, magnetic_to )
          end

          self
        end

        # make `id` magnetic_to
        def magnetic_to(id, magnetic_to)
          group, index = @groups.find(id) # this can be a future task!

          unless group # DISCUSS: future - should it be here?
            @future_magnetic_to[id] = magnetic_to
            return
          end

          arr = group[index].configuration.dup

          arr[0] = arr[0] + magnetic_to
          group.add(id, arr, replace: id)
        end

        # Returns array of tripletts.
        def to_a
          @groups.to_a
        end
      end
    end # DSL
  end
end
