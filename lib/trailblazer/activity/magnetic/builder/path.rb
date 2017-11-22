module Trailblazer
  module Activity::Magnetic
    class Builder
      class Path < Builder
        # @return ADDS
        def self.plan(options={}, normalizer=DefaultNormalizer, &block)
          builder = new(options, normalizer)

          # TODO: pass new edge color in block?
          builder.instance_exec(&block) #=> ADDS
        end

        def keywords
          [:type]
        end

        # strategy_options:
        #   :track_color
        #   :end_semantic
        def initialize(strategy_options={}, normalizer)
          super

          start_evt = Circuit::Start.new(:default)

          # TODO: use Start strategy that has only one plus_pole?
          add!( Path.method(:task), start_evt, id: "Start.default", magnetic_to: [], group: :start )


          # FIXME: fixme.
          track_color = strategy_options[:track_color] || :success
          end_semantic = strategy_options[:end_semantic] || :success

          end_evt = Activity::Magnetic.End(track_color, end_semantic)

          add!( Path.method(:End), end_evt, id: "End.#{track_color}", group: :end )
        end

        def task(*args, &block)
          add!( Path.method(:task), *args, &block )
        end

        DefaultNormalizer = ->(task, local_options) do
          local_options = { plus_poles: DefaultPlusPoles }.merge(local_options)
          [ task, local_options ]
        end

        DefaultPlusPoles = DSL::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Right, :success) => nil
        ).freeze

      # ONLY JOB: magnetic_to and Outputs ("Polarization") via PlusPoles.merge
      # Implements #task
        def self.task(task, track_color: :success, plus_poles: raise, type: :task, magnetic_to: nil, **, &block)
          return End(task, track_color: track_color) if type == :End # DISCUSS: should this dispatch be here?

          [
            # magnetic_to:
            magnetic_to || [track_color],
            # outputs:
            plus_poles.reconnect( :success => track_color )
          ]
        end

        def self.End(task, track_color: :success, **)
          [
            [track_color], {}
          ]
        end
      end # Path
    end # Builder
  end
end
