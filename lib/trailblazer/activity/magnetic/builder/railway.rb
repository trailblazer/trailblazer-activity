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

          # TODO: use Start strategy that has only one plus_pole?
          # add start and default end.
          add!(
            Path.InitialAdds( normalizer, strategy_options ) +
            self.class.InitialAdds( normalizer, strategy_options )
          )
        end

        def step(task, options={}, &block)
          adds = self.class.Step( @strategy_options, @normalizer, task, options, &block )

          add!(adds)
        end

        def fail(task, options={}, &block)
          adds = self.class.Fail( @strategy_options, @normalizer, task, options, &block )

          add!(adds)
        end

        def pass(task, options={}, &block)
          adds = self.class.Pass( @strategy_options, @normalizer, task, options, &block )

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

        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(failure_color:, **builder_options)
          # strategy_options = strategy_options.merge( failure_color: failure_color )

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

        def self.Step(strategy_options, normalizer, *args, &block)
          AddsFor( [Railway.method(:_Step), strategy_options], normalizer, *args, &block )
        end

        def self.Fail(strategy_options, normalizer, *args, &block)
          AddsFor( [Railway.method(:_Fail), strategy_options], normalizer, *args, &block )
        end

        def self.Pass(strategy_options, normalizer, *args, &block)
          AddsFor( [Railway.method(:_Pass), strategy_options], normalizer, *args, &block )
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
              magnetic_to,
              plus_poles.reconnect( :failure => @failure_color )
            ]
          end
        end

        def self._Pass(task, track_color: :success, failure_color: :failure, plus_poles: raise, **)
          [
            [track_color],
            plus_poles.reconnect( :success => track_color, :failure => track_color)
          ]
        end

        def self._Fail(task, track_color: :success, failure_color: :failure, plus_poles: raise, **)
          [
            [failure_color], # a fail task is magnetic to :failure
            plus_poles.reconnect( :success => failure_color, :failure => failure_color)
          ]
        end
      end # Path
    end # Builder
  end
end
