module Trailblazer
  module Activity::Magnetic
    class Builder
      class Railway < Builder
        def self.keywords
          [:type]
        end

        def initialize(normalizer, strategy_options={})
          strategy_options = { track_color: :success, end_semantic: :success,
            failure_color: :failure,
             }.merge(strategy_options)
          # FIXME: fixme.

          super

          add!(
            Railway.InitialAdds( strategy_options )   # add start, success end and failure end.
          )
        end

        def step(task, options={}, &block)
          polarizations = Railway.StepPolarizations( @builder_options )

          adds          = Railway.adds_for(polarizations, @normalizer, task, options, &block)

          add!(adds)
        end

        def fail(task, options={}, &block)
          polarizations = [Railway::FailPolarization.new( @builder_options )]

          adds          = Railway.adds_for(polarizations, @normalizer, task, options, &block)

          add!(adds)
        end

        def pass(task, options={}, &block)
          polarizations = [Railway::PassPolarization.new( @builder_options )]

          adds          = Railway.adds_for(polarizations, @normalizer, task, options, &block)

          add!(adds)
        end

        def self.DefaultNormalizer # FIXME: remove me, use Path.
          ->(task, local_options) do
            local_options = { plus_poles: DefaultPlusPoles }.merge(local_options)

            [ task, local_options ]
          end
        end

        DefaultPlusPoles = DSL::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Right, :success) => nil,
          Activity::Magnetic.Output(Circuit::Left,  :failure) => nil,
        ).freeze

        # Adds the End.failure end to the Path sequence.
        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(failure_color:, **builder_options)
          path_adds = Path.InitialAdds(**builder_options)

          end_adds = adds(
            "End.#{failure_color}", Activity::Magnetic.End(failure_color, :failure),

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

        class StepPolarization
          def initialize(track_color: :success, failure_color: :failure, **)
            @track_color, @failure_color = track_color, failure_color
          end

          def call(magnetic_to, plus_poles, options)
            [
              [@track_color],
              plus_poles.reconnect( :failure => @failure_color )
            ]
          end
        end

        class PassPolarization < StepPolarization
          def call(magnetic_to, plus_poles, options)
            [
              [@track_color],
              plus_poles.reconnect( :failure => @track_color, :success => @track_color )
            ]
          end
        end

        class FailPolarization < StepPolarization
          def call(magnetic_to, plus_poles, options)
            [
              [@failure_color],
              plus_poles.reconnect( :failure => @failure_color, :success => @failure_color )
            ]
          end
        end

      end # Railway
    end # Builder
  end
end
