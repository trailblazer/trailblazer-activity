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
        builder.instance_exec(&block) #=> ADDS
      end

      def initialize(normalizer, builder_options)
        @builder_options = builder_options
        @normalizer       = normalizer
        @adds             = []
      end

      # @private
      def self.finalize(adds)
        Finalizer.(adds)
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

          Activity::Magnetic.Output(signal, semantic)
        end

        def End(name, semantic)
          Activity::Magnetic.End(name, semantic)
        end

        def Path(track_color: "track_#{rand}", end_semantic: :success, **options)
          options = options.merge(track_color: track_color, end_semantic: end_semantic)

          # this block is called in DSL::ProcessTuples.
          ->(block) { [ track_color, Builder::Path.plan( options, @normalizer, &block ) ] }
        end
      end

      include DSLMethods

      private

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
      def self.adds_for(polarizations, normalizer, task, options, &block)
        # sort through the "original" user DSL options.
        options, local_options    = normalize( options, generic_keywords+keywords )
        options, sequence_options = normalize( options, sequence_keywords )

        task, local_options = normalizer.(task, local_options)
        initial_plus_poles = local_options[:plus_poles]



        polarizations_from_user_options, additional_adds = DSL::ProcessOptions.(local_options[:id], options, initial_plus_poles, &block) # TODO/FIXME: :add's are missing

        result = adds(local_options[:id], task, initial_plus_poles, polarizations, polarizations_from_user_options, options, sequence_options)

pp additional_adds

        result + additional_adds
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

    end

    module FastTrack

    end
    class FastTrack::Builder < Builder
      def self.keywords
        [:fail_fast, :pass_fast, :fast_track]
      end

      def initialize(builder_options={})
        super
        @adds += DSL::Path.initialize_sequence(builder_options)
        @adds += DSL::Railway.initialize_sequence(builder_options)
        @adds += DSL::FastTrack.initialize_sequence(builder_options)
      end

      def step(*args, &block)
        add!(DSL::FastTrack.method(:step), *args, &block)
      end
      def fail(*args, &block)
        add!(DSL::FastTrack.method(:fail), *args, &block)
      end
      def pass(*args, &block)
        add!(DSL::FastTrack.method(:pass), *args, &block)
      end
    end # Builder
  end
end


