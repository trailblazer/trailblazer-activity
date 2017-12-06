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
        def initialize(normalizer, builder_options={})
          builder_options = { track_color: :success, end_semantic: :success }.merge(builder_options)
          super

          # TODO: use Start strategy that has only one plus_pole?
          # add start and default end.
          add!(
            self.class.InitialAdds(builder_options)
          )
        end

        def task(task, options={}, &block)
          polarizations = Path.TaskPolarizations( @builder_options.merge(type: options[:type]) ) # DISCUSS: handle :type here? Really?

          insert_element!( Path, polarizations, task, options, &block )
        end


        def self.DefaultPlusPoles
          DSL::PlusPoles.new.merge(
            Activity.Output( Circuit::Right, :success ) => nil
          ).freeze
        end

        # @return [Adds] list of Adds instances that can be chained or added to an existing sequence.
        def self.InitialAdds(track_color:raise, end_semantic:raise, default_plus_poles: self.DefaultPlusPoles, track_end: Activity.End(track_color, end_semantic), **o)

          builder_options={ track_color: track_color, end_semantic: end_semantic }

          start_adds = adds(
            "Start.default", Circuit::Start.new(:default),

            default_plus_poles,
            TaskPolarizations(builder_options),
            [],

            {}, { group: :start },
            [] # magnetic_to
          )

          end_adds = adds(
            "End.#{track_color}", track_end,

            {}, # plus_poles
            TaskPolarizations(builder_options.merge( type: :End )),
            [],

            {}, { group: :end }
          )

          start_adds + end_adds
        end

        def self.TaskPolarizations(track_color:raise, type: :task, **o)
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
