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

        # In most cases, a task has a binary signal, which is why we decided to make that
        # the default output set.
        def self.default_outputs
          {
            :success => Activity.Output(Activity::Right, :success),
            :failure => Activity.Output(Activity::Left,  :failure)
          }
        end

        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(**options)
          StartAdds(**options) + EndAdds(**options)
        end

        # TODO: make this nicer.
        def self.StartAdds(track_color:, end_semantic:, start_outputs: {success: self.default_outputs[:success]}, **)
          builder_options={ track_color: track_color, end_semantic: end_semantic }

          adds(
            Activity::Start.new(semantic: :default),
            TaskPolarizations(builder_options),
            {}, { group: :start },
            id:           "Start.default",
            magnetic_to:  [],
            plus_poles:   PlusPoles.initial(start_outputs), # FIXME: this is actually redundant with Normalizer
          )
        end

        # TODO: make this nicer.
        def self.EndAdds(track_color:, end_semantic:, track_end: Activity.End(end_semantic), end_id: nil, **)
          # an end can either be a reference to another task,
          # or a "real" end event.
          if end_id
            [[
              :magnetic_to,
              [ end_id, [track_color] ]
            ]]
          else
            builder_options={ track_color: track_color, end_semantic: end_semantic }

            adds(
              track_end,
              EndEventPolarizations(builder_options), # only sets :magnetic_to.
              {}, { group: :end },
              id:         "End.#{track_color}",
              plus_poles: {},
              magnetic_to: nil,
            )
          end
        end

        def self.TaskPolarizations(track_color:, **)
          [TaskPolarization.new( track_color: track_color )]
        end

        def self.EndEventPolarizations(track_color:, **)
          [EndEventPolarization.new( track_color: track_color )]
        end

        class TaskPolarization
          def initialize(track_color:)
            @track_color = track_color
          end

          def call(magnetic_to, plus_poles, options)
            [
              magnetic_to || [@track_color],
              plus_poles.reconnect( :success => @track_color )
            ]
          end
        end # TaskPolarization

        class EndEventPolarization < TaskPolarization
          def call(magnetic_to, plus_poles, options)
            [
              magnetic_to || [@track_color],
              {}
            ]
          end
        end # EndEventPolarization
      end # Path
    end # Builder
  end
end
