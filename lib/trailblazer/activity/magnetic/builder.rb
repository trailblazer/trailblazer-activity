require "trailblazer/activity/magnetic/finalizer"

module Trailblazer
  module Activity::Magnetic
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

      def initialize(normalizer, strategy_options)
        @strategy_options = strategy_options
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

      # merge @strategy_options (for the track colors)
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
      def self.Adds(strategy_cfg, normalizer, task, options, &block)
        strategy, strategy_options = strategy_cfg

        options, local_options    = normalize( options, generic_keywords+keywords )
        options, sequence_options = normalize( options, sequence_keywords )

        task, local_options = normalizer.(task, local_options)

        # Strategy receives :plus_poles, :id, :track_color, :end_semantic
        DSL::ProcessElement.( task, options,
          id:               local_options[:id],
          # the strategy (Path.task) has nothing to do with (Output=>target) tuples
          strategy:         [ strategy, strategy_options.merge( local_options ) ],
          sequence_options: sequence_options,
          &block
        )
      end
    end

    module FastTrack

    end
    class FastTrack::Builder < Builder
      def self.keywords
        [:fail_fast, :pass_fast, :fast_track]
      end

      def initialize(strategy_options={})
        super
        @adds += DSL::Path.initialize_sequence(strategy_options)
        @adds += DSL::Railway.initialize_sequence(strategy_options)
        @adds += DSL::FastTrack.initialize_sequence(strategy_options)
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


