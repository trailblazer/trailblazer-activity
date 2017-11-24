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
        def self.InitialAdds(track_color:, end_semantic:, **)
          builder_options={ track_color: track_color, end_semantic: end_semantic }

          start_adds = adds(
            "Start.default", Circuit::Start.new(:default),

            DefaultPlusPoles,
            TaskPolarizations(builder_options),
            [],

            {},
            { group: :start },
            [] # magnetic_to
          )

          end_adds = adds(
            "End.#{track_color}", Activity::Magnetic.End(track_color, end_semantic),

            {}, # plus_poles
            TaskPolarizations(builder_options.merge( type: :End )),
            [],

            {},
            { group: :end }
          )

          start_adds + end_adds
        end

        def self.TaskPolarizations(track_color:, type: :task, **)
          return [EndPolarization.new( track_color: track_color )] if type == :End # DISCUSS: should this dispatch be here?

          [TaskPolarization.new( track_color: track_color )]
        end

        class TaskPolarization
          def initialize( track_color: )
            @track_color = track_color
          end

          def call(magnetic_to, plus_poles, options)
            [
              magnetic_to || @track_color,
              plus_poles.reconnect( :success => @track_color )
            ]
          end
        end # TaskPolarization

        class EndPolarization < TaskPolarization
          def call(magnetic_to, plus_poles, options)
            [
              magnetic_to || @track_color,
              {}
            ]
          end
        end # EndPolarization
      end # Path
    end # Builder
  end
end
