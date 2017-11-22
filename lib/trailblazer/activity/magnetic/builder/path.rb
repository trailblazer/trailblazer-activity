module Trailblazer
  module Activity::Magnetic
    class Builder
      class Path < Builder
        def self.keywords
          [:type]
        end

        # strategy_options:
        #   :track_color
        #   :end_semantic
        def initialize(normalizer, strategy_options={})
          strategy_options = { track_color: :success, end_semantic: :success }.merge(strategy_options)
          super

          # TODO: use Start strategy that has only one plus_pole?
          # add start and default end.
          add!(
            self.class.InitialAdds( normalizer, strategy_options )
          )
        end

        def task(task, options={}, &block)
          adds = self.class.Task( @strategy_options, @normalizer, task, options, &block )

          add!(adds)
        end

        def self.DefaultNormalizer
          ->(task, local_options) do
            local_options = { plus_poles: DefaultPlusPoles }.merge(local_options)
            [ task, local_options ]
          end
        end

        DefaultPlusPoles = DSL::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Right, :success) => nil
        ).freeze

        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(normalizer, track_color:, end_semantic:, **strategy_options)
          strategy_options = strategy_options.merge( track_color: track_color, end_semantic: end_semantic )

          Task(strategy_options, normalizer, Circuit::Start.new(:default),                      id: "Start.default", magnetic_to: [], group: :start ) +
          Task(strategy_options, normalizer, Activity::Magnetic.End(track_color, end_semantic), id: "End.#{track_color}", type: :End, group: :end )
        end

        def self.Task(strategy_options, normalizer, *args, &block)
          Adds( [Path.method(:_Task), strategy_options], normalizer, *args, &block )
        end

      # ONLY JOB: magnetic_to and Outputs ("Polarization") via PlusPoles.merge
      # Implements #task
        def self._Task(task, track_color:raise, plus_poles:raise, type: :task, magnetic_to: nil, **, &block)
          return End(task, track_color: track_color) if type == :End # DISCUSS: should this dispatch be here?

          [
            # magnetic_to:
            magnetic_to || [track_color],
            # outputs:
            plus_poles.reconnect( :success => track_color )
          ]
        end

        def self.End(task, track_color:raise, **)
          [
            [track_color], {}
          ]
        end
      end # Path
    end # Builder
  end
end
