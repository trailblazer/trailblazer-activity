module Trailblazer
  module Activity::Magnetic
    class Builder
      def self.build(options={}, &block)
        adds = plan( options, &block )

        finalize(adds)
      end

      # TODO: remove, only for testing.
      # @return Tripletts
      def self.draft(*args, &block)
        adds = plan( *args, &block )

        return adds_to_tripletts(adds), adds
      end
      def draft
        return Builder.adds_to_tripletts(@adds), @adds # remove me.
      end

      # @private
      def self.finalize(adds)
        tripletts = adds_to_tripletts(adds)

        circuit_hash = tripletts_to_circuit_hash( tripletts )

        circuit_hash_to_process( circuit_hash )
      end

      def self.adds_to_tripletts(adds)
        alterations = DSL::Alterations.new

        adds.each { |method, cfg| alterations.send( method, *cfg ) }

        alterations.to_a
      end

      def self.tripletts_to_circuit_hash(tripletts)
        Trailblazer::Activity::Magnetic::Generate.( tripletts )
      end

      def self.circuit_hash_to_process(circuit_hash)
        end_events = end_events_for(circuit_hash)

        return Activity::Process.new( circuit_hash, end_events ), end_events
      end

      # Filters out unconnected ends, e.g. the standard end in nested tracks that weren't used.
      def self.end_events_for(circuit_hash)
        tasks_with_incoming_edge = circuit_hash.values.collect { |connections| connections.values }.flatten(1)

        ary = circuit_hash.collect do |task, connections|
          task.kind_of?(Circuit::End) &&
            connections.empty? &&
            tasks_with_incoming_edge.include?(task) ? [task, task.instance_variable_get(:@options)[:semantic]] : nil
        end

        Hash[ ary.compact ]
      end

      def initialize(strategy_options={}, normalizer)
        @strategy_options = strategy_options
        @normalizer       = normalizer
        @adds             = []
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
          ->(block) { [ track_color, Path::Builder.plan( options, @normalizer, &block ) ] }
        end
      end

      include DSLMethods

      private


      # merge @strategy_options (for the track colors)
      # normalize options
      def add(strategy, task, options={}, &block)
        local_options, options = normalize(options, keywords)

        task, local_options = @normalizer.(task, local_options)

        @adds += DSL::ProcessElement.( @sequence, task, options, id: local_options[:id],
          # the strategy (Path.task) has nothing to do with (Output=>target) tuples
          strategy: [ strategy, @strategy_options.merge( local_options ) ],
          &block
        )
      end

      # Produce two hashes, one "local" options with DSL-specific options such as `:fast_track`,
      # one with generic DSL options, for example tuples like `Right=>Output(:failure)`.
      def normalize(options, local_keys)
        local, foreign = {}, {}
        options.each { |k,v| local_keys.include?(k) ? local[k] = v : foreign[k] = v }

        return local, foreign
      end
    end


    module FastTrack

    end
    class FastTrack::Builder < Builder
      def keywords
        [:id, :plus_poles, :fail_fast, :pass_fast, :fast_track]
      end

      def initialize(strategy_options={})
        super
        @adds += DSL::Path.initialize_sequence(strategy_options)
        @adds += DSL::Railway.initialize_sequence(strategy_options)
        @adds += DSL::FastTrack.initialize_sequence(strategy_options)
      end

      def step(*args, &block)
        add(DSL::FastTrack.method(:step), *args, &block)
      end
      def fail(*args, &block)
        add(DSL::FastTrack.method(:fail), *args, &block)
      end
      def pass(*args, &block)
        add(DSL::FastTrack.method(:pass), *args, &block)
      end
    end

    class Path
      class Builder < Builder
        # @return ADDS
        def self.plan(options={}, normalizer=DefaultNormalizer, &block)
          builder = new(options, normalizer)

          # TODO: pass new edge color in block?
          builder.instance_exec(&block) #=> ADDS
        end

        def keywords
          [:id, :plus_poles]
        end

        # strategy_options:
        #   :track_color
        #   :end_semantic
        def initialize(strategy_options={}, normalizer)
          super
          @adds += DSL::Path.initialize_sequence(strategy_options)
        end

        def task(*args, &block)
          add( DSL::Path.method(:task), *args, &block )
        end

        DefaultNormalizer = ->(task, local_options) do
          local_options = { plus_poles: DefaultPlusPoles }.merge(local_options)
          [ task, local_options ]
        end

        DefaultPlusPoles = DSL::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Right, :success) => nil
        ).freeze
      end
    end # Builder
  end
end


