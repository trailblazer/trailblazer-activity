module Trailblazer
  module Activity::Magnetic
    # A plus pole is associating an Output{:signal, :semantic} to a magnetic :color.
    #
    # When it comes to connecting tasks to each other, PlusPoles is the most important object
    # here. When a task is added via the DSL, a PlusPoles is set up, and the DSL adds polarizations
    # from the implementation and from the options (e.g. `Outputs(..) => ..`).
    #
    # These are then finalized and return the effective plus poles

    # Polarization is one or multiple calls to PlusPoles





    # Output(:signal, :semantic) => :color
    # add / merge
    #   change existing, => color
    #
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

        # filter all outputs with a color that already exists.
        overrides = output_to_color.find_all { |output, color| !existing_colors.include?(color) }
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

      # Compile one {PlusPoles} instance from all a sequence of {Polarization}s.
      # This is usually called once per `step` DSL call.
      #
      # @api private
      def self.apply_polarizations(polarizations, magnetic_to, plus_poles, options)
        magnetic_to, plus_poles = polarizations.inject([magnetic_to, plus_poles]) do |args, pol|
          magnetic_to, plus_poles = pol.(*args, options)
        end

        return magnetic_to, plus_poles.to_a
      end

      # The DSL is a series of transformations that yield in tasks with several PlusPole instances each.
      #
      # @api private
      def to_a
        @plus_poles.values.collect { |output, color| PlusPole.new(output, color) }
      end

      # Builds PlusPoles from { semantic => Output }, which, surprisingly, is exactly what Activity::outputs looks like.
      # The plus pole's color is set to the output's semantic.
      def self.from_outputs(outputs)
        ary = outputs.collect { |semantic, output| [ output, semantic ] }

        new.merge(::Hash[ary])
      end

      # FIXME: should this be a hash or whatever?
      #
      # @return Hash All {Output}s mapped to their semantic: `{ Output(Right, :success) => :success }`
      def self.initial(outputs)
        new.merge(Hash[ outputs.collect { |semantic, output| [output, semantic] } ])
      end
    end
  end
end
