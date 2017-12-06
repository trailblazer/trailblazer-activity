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
      #
      # @privat
      # @note This is private until we know what we want.
      class PlusPoles
        def initialize(plus_poles={})
          @plus_poles = plus_poles.freeze
        end

        #   merge( Activity::Magnetic.Output(Right, :success) => :success
        def merge(output_to_color)
          overrides = ::Hash[ output_to_color.collect { |output, color| [ output.semantic, [output, color] ] } ]
          PlusPoles.new(@plus_poles.merge(overrides))
        end

        def reverse_merge(output_to_color)
          existing_colors = @plus_poles.values.collect { |pole_cfg| pole_cfg.last }

          overrides = output_to_color.find_all { |output, color| !existing_colors.include?(color) } # filter all outputs with a color that already exists.
          merge(overrides)
        end

        def reconnect(semantic_to_color)
          ary = semantic_to_color.collect do |semantic, color|
            existing_output, _ = @plus_poles[semantic]

            next unless existing_output

            [ Activity.Output(existing_output.signal, existing_output.semantic), color ]
          end

          merge( ::Hash[ary.compact] )
        end

        # The DSL is a series of transformations that yield in tasks with several PlusPole instances each.
        def to_a
          @plus_poles.values.collect { |output, color| PlusPole.new(output, color) }
        end

        #---
        #-  builders
        def self.from_outputs(outputs)
          ary = outputs.collect { |evt, semantic| [ Activity::Output(evt, semantic), semantic ] }

          new.merge(::Hash[ary])
        end
      end
    end
  end
end
