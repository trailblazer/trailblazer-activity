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

        def self.plan(options={}, normalizer=DefaultNormalizer.new(plus_poles: default_plus_poles), &block)
          plan_for( *Railway.for(normalizer, options), &block )
        end

        def step(task, options={}, &block)
          insert_element( Railway, Railway.StepPolarizations(@builder_options), task, options, &block )
        end

        def fail(task, options={}, &block)
          insert_element( Railway, Railway.FailPolarizations(@builder_options), task, options, &block )
        end

        def pass(task, options={}, &block)
          insert_element( Railway, Railway.PassPolarizations(@builder_options), task, options, &block )
        end

        def self.default_plus_poles
          DSL::PlusPoles.new.merge(
            Activity.Output(Activity::Right, :success) => nil,
            Activity.Output(Activity::Left,  :failure) => nil,
          ).freeze
        end

        # Adds the End.failure end to the Path sequence.
        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(failure_color:raise, failure_end: Activity.End(failure_color, :failure), **builder_options)
          path_adds = Path.InitialAdds(**builder_options)

          end_adds = adds(
            "End.#{failure_color}", failure_end,

            {}, # plus_poles
            Path::TaskPolarizations(builder_options.merge( type: :End )),
            [],

            {},
            { group: :end },
            [failure_color]
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
