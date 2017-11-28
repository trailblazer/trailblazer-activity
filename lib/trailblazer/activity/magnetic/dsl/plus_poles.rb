module Trailblazer
  module Activity::Magnetic
    module DSL
      # Output(:signal, :semantic) => :color
      # add / merge
      #   change existing, => color
      #
      # Mutable DSL datastructure for managing all PlusPoles for a particular task.
      #
      # Produces [ PlusPole, PlusPole, ] via `to_a`.
      class PlusPoles
        def initialize(plus_poles={})
          @plus_poles = plus_poles.freeze
        end

        def merge(map)
          overrides = ::Hash[ map.collect { |output, color| [ output.semantic, [output, color] ] } ]
          PlusPoles.new(@plus_poles.merge(overrides))
        end

        def reconnect(semantic_to_color)
          ary = semantic_to_color.collect do |semantic, color|
            existing_output, _ = @plus_poles[semantic]
            # raise "output for #{semantic.inspect} does not exist" # TODO: test me.
            [ Activity::Magnetic.Output(existing_output.signal, existing_output.semantic), color ]
          end

          merge( ::Hash[ary] )
        end

        def to_a
          @plus_poles.values.collect { |output, color| PlusPole.new(output, color) }
        end
      end
    end
  end
end
