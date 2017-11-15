module Trailblazer
  module Activity::Magnetic
    class Builder
      extend Forwardable
      def_delegators DSL, :Output, :End # DISCUSS: Builder could be the DSL namespace?

      def initialize(strategy_options={})
        @strategy_options = strategy_options

        @sequence = Alterations.new
      end

      def draft
        @sequence.to_a
      end

      private

      # merge @strategy_options (for the track colors)
      # normalize options
      def add(strategy, task, options, &block)
        local_options, options = normalize(options, keywords)

        @sequence = DSL::ProcessElement.( @sequence, task, options, id: local_options[:id],
          strategy: [ strategy, @strategy_options.merge( local_options ) ],
          &block
        )
      end

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
        sequence = super
        sequence = DSL::Path.initialize_sequence(sequence, strategy_options)
        sequence = DSL::Railway.initialize_sequence(sequence, strategy_options)
        sequence = DSL::FastTrack.initialize_sequence(sequence, strategy_options)

        @sequence = sequence
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

      def finalize()
        tripletts = draft
        # pp tripletts

        circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
      end

      def to_activity
        tripletts = dsl.to_a
        # pp tripletts

        circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
      end
      def self.build
        new
        instance_exec
        to_activity
      end
    end

    class Path
      class Builder < Builder
        def keywords
          [:id, :plus_poles]
        end

        def initialize(strategy_options={})
          sequence = super
          sequence = DSL::Path.initialize_sequence(sequence, strategy_options)

          @sequence = sequence
        end

        def task(*args, &block)
          add( DSL::Path.method(:task), *args, &block )
        end
      end
    end # Builder
  end
end


