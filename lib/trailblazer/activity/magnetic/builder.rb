require "trailblazer/activity/magnetic/finalizer"

module Trailblazer
  module Activity::Magnetic

    # TODO: move?
    module Options
      # Produce two hashes, one "local" options with DSL-specific options such as `:fast_track`,
      # one with generic DSL options, for example tuples like `Right=>Output(:failure)`.
      def self.normalize(options, local_keys)
        local, foreign = {}, {}
        options.each { |k,v| local_keys.include?(k) ? local[k] = v : foreign[k] = v }

        return foreign, local
      end
    end

    # Called from Path/Railway/FastTrack, creates the specific {Builder} instance.
    def self.Builder(implementation, normalizer, builder_options={})
      builder = implementation.new(normalizer, builder_options.freeze).freeze # e.g. Path.new(...)

      return builder, implementation.InitialAdds(builder_options)
    end

    class Builder
      def initialize(normalizer, builder_options)
        @normalizer, @builder_options = normalizer, builder_options
      end

      def self.merge(activity_adds, merged_adds)
        merged_adds = merged_adds[2..-1] || []

        activity_adds + merged_adds
      end

      # DSL method to create a Path within an activity which is embedded.
      #
      # Output(:success) => Path() {}
      def Path(*args)
        Activity::DSL::Helper.Path(@normalizer, *args)
      end

      # Public top-level entry point.
      def insert(strategy, polarizer, task, options, &block)
        normalizer = options[:normalizer] || @normalizer # DISCUSS: do this at a deeper point?

        task, local_options, connection_options, sequence_options = normalizer.(task, options)

        polarizations = strategy.send(polarizer, @builder_options) # Railway.StepPolarizations( @builder_options )

        insert_element( polarizations, task, local_options, connection_options, sequence_options, &block )
      end

      private

      # Internal top-level entry point to add task(s) and connections.
      # High level interface for DSL calls like ::task or ::step.
      def insert_element(polarizations, task, local_options, connection_options, sequence_options, &block)
        adds, *returned_options = Builder.adds_for(polarizations, task, local_options, connection_options, sequence_options, &block)
      end

      # @return Adds
      def self.adds_for(polarizations, task, local_options, connection_options, sequence_options, &block)
        # go through all wiring options such as Output()=>:color.
        polarizations_from_user_options, additional_adds = process_dsl_options(connection_options, local_options, &block)

        polarizations = polarizations + polarizations_from_user_options

        result = adds(task, polarizations, local_options, sequence_options, local_options)

        return result + (local_options[:adds] || []) + additional_adds, task, local_options, connection_options, sequence_options
      end

      def self.process_dsl_options(options, id:nil, plus_poles:, **, &block)
        DSL::ProcessOptions.(id, options, plus_poles, &block)
      end

      # Low-level interface for DSL calls (e.g. Start, where "you know what you're doing")
      # @private
      def self.adds(task, polarizations, options, sequence_options, magnetic_to:nil, id:nil, plus_poles:, **) # DISCUSS: no :id ?
        magnetic_to, plus_poles = PlusPoles.apply_polarizations(
          polarizations,
          magnetic_to,
          plus_poles,
          options
        )

        Add( id, task, magnetic_to, plus_poles,
          options,         #{ fast_track: true },
          sequence_options #{ group: :main }
        )
      end

      def self.Add(id, task, magnetic_to, plus_poles, options, sequence_options)
        [
          [ :add, [id, [ magnetic_to, task, plus_poles ], sequence_options] ],
        ]
      end
    end # Builder
  end
end


