require "trailblazer/activity/magnetic/finalizer"

module Trailblazer
  module Activity::Magnetic
    module Polarization
                # Called once per DSL method call, e.g. ::step.
                #
                # The idea is to chain a bunch of PlusPoles transformations (and magnetic_to "transformations")
                # for each DSL call, and thus realize things like path+railway+fast_track
                def self.apply(polarizations, magnetic_to, plus_poles, options)
                  polarizations.inject([magnetic_to, plus_poles]) do |args, pol|
                    magnetic, plus_poles = pol.(*args, options)
                  end
                end
              end


    class Builder
      def self.build(options={}, &block)
        adds = plan( options, &block )

        finalize(adds)
      end

      # @return ADDS
      def self.plan(options={}, normalizer=self.DefaultNormalizer, &block)
        builder = new(normalizer, options)

        # TODO: pass new edge color in block?
        builder.(&block) #=> ADDS
      end

      def initialize(normalizer, builder_options)
        @builder_options = builder_options
        @normalizer       = normalizer
        @adds             = []
      end

      # Evaluate user's block and return the new ADDS.
      # Used in Builder::build.
      def call(&block)
        instance_exec(&block)
        @adds
      end

      # @private
      def self.finalize(adds)
        Finalizer.(adds)
      end

      def self.merge(activity, merged)
        merged = merged[2..-1] || []

        activity + merged
      end

      # TODO: remove, only for testing.
      # @return Tripletts
      def self.draft(*args, &block)
        adds = plan( *args, &block )

        return Finalizer.adds_to_tripletts(adds), adds
      end
      def draft
        return Finalizer.adds_to_tripletts(@adds), @adds # remove me.
      end

      module DSLMethods
        #   Output( Left, :failure )
        #   Output( :failure ) #=> Output::Semantic
        def Output(signal, semantic=nil)
          return DSL::Output::Semantic.new(signal) if semantic.nil?

          Activity.Output(signal, semantic)
        end

        def End(name, semantic)
          Activity.End(name, semantic)
        end

        def Path(track_color: "track_#{rand}", end_semantic: :success, **options)
          options = options.merge(track_color: track_color, end_semantic: end_semantic)

          # this block is called in DSL::ProcessTuples.
          ->(block) { [ track_color, Builder::Path.plan( options, @normalizer, &block ) ] }
        end
      end

      include DSLMethods

      private

      # Internal top-level entry point to add task(s) and connections.
      def insert_element!(impl, polarizations, task, options, &block)
        adds, *returned_options = Builder.adds_for(polarizations, @normalizer, impl.keywords, task, options, &block)

        adds = add!(adds)

        return adds, *returned_options
      end

      # merge @builder_options (for the track colors)
      # normalize options
      def add!(adds)
        @adds += adds
      end

      # Options valid for all DSL calls with this Builder framework.
      def self.generic_keywords
        [ :id, :plus_poles, :magnetic_to ]
      end

      def self.sequence_keywords
        [ :group, :before, :after, :replace, :delete ] # hard-wires Builder to Sequence/Alterations.
      end

      # Produce two hashes, one "local" options with DSL-specific options such as `:fast_track`,
      # one with generic DSL options, for example tuples like `Right=>Output(:failure)`.
      def self.normalize(options, local_keys)
        local, foreign = {}, {}
        options.each { |k,v| local_keys.include?(k) ? local[k] = v : foreign[k] = v }

        return foreign, local
      end

      # @return Adds
      # High level interface for DSL calls like ::task or ::step.
      # TODO: RETURN ALL OPTIONS
      def self.adds_for(polarizations, normalizer, keywords, task, options, &block)
        task, local_options, options, sequence_options = normalize_options(normalizer, keywords, task, options)

        initial_plus_poles = local_options[:plus_poles]
        magnetic_to        = local_options[:magnetic_to]

        polarizations_from_user_options, additional_adds = DSL::ProcessOptions.(local_options[:id], options, initial_plus_poles, &block)

        result = adds(local_options[:id], task, initial_plus_poles, polarizations, polarizations_from_user_options, local_options, sequence_options, magnetic_to)

        return result + additional_adds, task, local_options, options, sequence_options
      end

      # @private
      def self.normalize_options(normalizer, keywords, task, options)
         # sort through the "original" user DSL options.
        options, local_options    = normalize( options, generic_keywords+keywords ) # DISCUSS:
        options, sequence_options = normalize( options, sequence_keywords )

        task, local_options, sequence_options = normalizer.(task, local_options, sequence_options)

        return task, local_options, options, sequence_options
      end

      # Low-level interface for DSL calls (e.g. Start, where "you know what you're doing")
      def self.adds(id, task, initial_plus_poles, polarization, polarizations_from_user_options, options, sequence_options, magnetic_to = nil)
        polarizations = polarization + polarizations_from_user_options

        Apply(id, task, magnetic_to, initial_plus_poles, polarizations,
          options, #{ fast_track: true },
          sequence_options #{ group: :main }
        )
      end

      def self.Apply(id, task, magnetic_to, plus_poles, polarizations, options, sequence_options)
        magnetic_to, plus_poles = Polarization.apply(polarizations, magnetic_to, plus_poles, options)

        add = [ :add, [id, [ magnetic_to, task, plus_poles.to_a ], sequence_options] ]

        [ add ]
      end

      def self.DefaultNormalizer(default_plus_poles=self.DefaultPlusPoles)
        ->(task, local_options, sequence_options) do
          local_options = { plus_poles: default_plus_poles }.merge(local_options)

          return task, local_options, sequence_options
        end
      end

    end # Builder
  end
end


