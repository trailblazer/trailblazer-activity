module Trailblazer
  module Activity::Magnetic
    class Builder

      class Path < Builder
          # strategy_options:
          #   :track_color
          #   :end_semantic
        def self.for(normalizer, builder_options={}) # Build the Builder.
          Activity::Magnetic::Builder(
            Path,
            normalizer,
            { track_color: :success, end_semantic: :success }.merge( builder_options )
          )
        end

        def task(task, options={}, &block)
          polarizations = Path.TaskPolarizations( @builder_options.merge( type: options[:type] ) ) # DISCUSS: handle :type here? Really?

          return Path, polarizations, task, options, block
        end


        def self.default_plus_poles
          DSL::PlusPoles.new.merge(
            Activity.Output( Activity::Right, :success ) => nil
          ).freeze
        end

        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(track_color:raise, end_semantic:raise, default_plus_poles: self.default_plus_poles, track_end: Activity.End(end_semantic), **)

          builder_options={ track_color: track_color, end_semantic: end_semantic }

          start_adds = adds(
            Activity::Start.new(:default),

            TaskPolarizations(builder_options),

            {}, { group: :start },

            id:           "Start.default",
            magnetic_to:  [],
            plus_poles:   default_plus_poles
          )

          end_adds = adds(
            track_end,

            TaskPolarizations(builder_options.merge( type: :End )),

            {}, { group: :end },

            id:         "End.#{track_color}",
            plus_poles: {},
            magnetic_to: nil,
          )

          start_adds + end_adds
        end

        def self.TaskPolarizations(track_color:raise, type: :task, **)
          return [EndPolarization.new( track_color: track_color )] if type == :End # DISCUSS: should this dispatch be here?

          [TaskPolarization.new( track_color: track_color )]
        end

        class TaskPolarization
          def initialize( track_color:raise )
            @track_color = track_color
          end

          def call(magnetic_to, plus_poles, options)
            [
              magnetic_to || [@track_color],
              plus_poles.reconnect( :success => @track_color )
            ]
          end
        end # TaskPolarization

        class EndPolarization < TaskPolarization
          def call(magnetic_to, plus_poles, options)
            [
              magnetic_to || [@track_color],
              {}
            ]
          end
        end # EndPolarization
      end # Path
    end # Builder
  end
end
