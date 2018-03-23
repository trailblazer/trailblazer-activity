module Trailblazer
  module Activity::Magnetic
    class Builder
      class Railway < Builder
        def self.for(normalizer, builder_options={}) # Build the Builder.
          Activity::Magnetic::Builder(
            Railway,
            normalizer,
            { track_color: :success, end_semantic: :success, failure_color: :failure }.merge( builder_options )
          )
        end

        # Adds the End.failure end to the Path sequence.
        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(failure_color:raise, failure_end: Activity.End(failure_color), **builder_options)
          path_adds = Path.InitialAdds(**builder_options)

          end_adds = adds(
            failure_end,

            Path::EndEventPolarizations(builder_options),

            {},
            { group: :end },

            magnetic_to:  [failure_color],
            id:           "End.#{failure_color}",
            plus_poles:   {},
          )

          path_adds + end_adds
        end

        # ONLY JOB: magnetic_to and Outputs ("Polarization") via PlusPoles.merge
        def self.StepPolarizations(**options)
          [
            *Path.TaskPolarizations(options),
            StepPolarization.new(options)
          ]
        end

        def self.PassPolarizations(options)
          [
            Railway::PassPolarization.new( options )
          ]
        end

        def self.FailPolarizations(options)
          [
            Railway::FailPolarization.new( options )
          ]
        end

        class StepPolarization
          def initialize(track_color: :success, failure_color: :failure, **o)
            @track_color, @failure_color = track_color, failure_color
          end

          # Returns the polarization for a DSL call. Takes care of user options such as :magnetic_to.
          def call(magnetic_to, plus_poles, options)
            [
              magnetic_to || default_magnetic_to,
              plus_poles_for(plus_poles, options),
            ]
          end

          private

          def plus_poles_for(plus_poles, options)
            plus_poles.reconnect( :failure => @failure_color )
          end

          def default_magnetic_to
            [@track_color]
          end
        end

        class PassPolarization < StepPolarization
          def plus_poles_for(plus_poles, options)
            plus_poles.reconnect( :failure => @track_color, :success => @track_color )
          end
        end

        class FailPolarization < StepPolarization
          def default_magnetic_to
            [@failure_color]
          end

          def plus_poles_for(plus_poles, options)
            plus_poles.reconnect( :failure => @failure_color, :success => @failure_color )
          end
        end

      end # Railway
    end # Builder
  end
end
