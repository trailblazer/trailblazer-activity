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

    def self.Builder(implementation, normalizer, builder_options={})
      builder = implementation.new(normalizer, builder_options.freeze).freeze # e.g. Path.new(...)

      return builder, implementation.InitialAdds(builder_options)
    end

    class Builder

      def self.plan_for(builder, adds, &block)
        adds += Block.new(builder).(&block) # returns ADDS
      end

      def self.build(options={}, &block)
        adds = plan( options, &block )

        Finalizer.(adds)
      end

      def initialize(normalizer, builder_options)
        @normalizer, @builder_options = normalizer, builder_options
      end

      def self.merge(activity, merged)
        merged = merged[2..-1] || []

        activity + merged
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
      def insert_element(impl, polarizations, task, options, &block)
        normalizer = options[:normalizer] || @normalizer # DISCUSS: do this at a deeper point?

        adds, *returned_options = Builder.adds_for(polarizations, normalizer, task, options, &block)
      end

      def self.sequence_keywords
        [ :group, :before, :after, :replace, :delete ] # hard-wires Builder to Sequence/Alterations.
      end



      # @return Adds
      # High level interface for DSL calls like ::task or ::step.
      # TODO: RETURN ALL OPTIONS
      def self.adds_for(polarizations, normalizer, task, options, &block)
        task, local_options, options, sequence_options = normalize_options(normalizer, task, options)

        initial_plus_poles = local_options[:plus_poles]
        magnetic_to        = local_options[:magnetic_to]
        adds               = local_options[:adds] || []

        # go through all wiring options such as Output()=>:color.
        polarizations_from_user_options, additional_adds = DSL::ProcessOptions.(local_options[:id], options, initial_plus_poles, &block)

        result = adds(local_options[:id], task, initial_plus_poles, polarizations, polarizations_from_user_options, local_options, sequence_options, magnetic_to)

        return result + adds + additional_adds, task, local_options, options, sequence_options
      end

      # @private
      def self.normalize_options(normalizer, task, options)
        keywords = extract_dsl_keywords(options)

         # sort through the "original" user DSL options.
        options, local_options          = Options.normalize( options, keywords ) # DISCUSS:
        local_options, sequence_options = Options.normalize( local_options, sequence_keywords )

        task, local_options, options, sequence_options = normalizer.(task, local_options, options, sequence_options)

        return task, local_options, options, sequence_options
      end

      # Filter out connections, e.g. `Output(:fail_fast) => :success` and return only the keywords like `:id` or `:replace`.
      def self.extract_dsl_keywords(options, connection_classes = [Activity::Output, DSL::Output::Semantic])
        options.keys - options.keys.find_all { |k| connection_classes.include?( k.class ) }
      end

      # Low-level interface for DSL calls (e.g. Start, where "you know what you're doing")
      # @private
      def self.adds(id, task, initial_plus_poles, polarization, polarizations_from_user_options, options, sequence_options, magnetic_to = nil)
        magnetic_to, plus_poles = apply_polarizations(
          polarization + polarizations_from_user_options,
          magnetic_to,
          initial_plus_poles,
          options
        )

        Add( id, task, magnetic_to, plus_poles,
          options,         #{ fast_track: true },
          sequence_options #{ group: :main }
        )
      end

      # Called once per DSL method call, e.g. ::step.
      #
      # The idea is to chain a bunch of PlusPoles transformations (and magnetic_to "transformations")
      # for each DSL call, and thus realize things like path+railway+fast_track
      def self.apply_polarizations(polarizations, magnetic_to, plus_poles, options)
        polarizations.inject([magnetic_to, plus_poles]) do |args, pol|
          magnetic, plus_poles = pol.(*args, options)
        end
      end

      def self.Add(id, task, magnetic_to, plus_poles, options, sequence_options)
        [
          [ :add, [id, [ magnetic_to, task, plus_poles.to_a ], sequence_options] ],
        ]
      end

      class DefaultNormalizer
        def initialize( **default_options )
          raise "you didn't specify default :plus_poles" unless default_options[:plus_poles]

          @default_options = default_options
        end

        # called for every ::task, ::step call etc to defaultize the `local_options`.
        def call(task, local_options, options, sequence_options)
          local_options = @default_options.merge(local_options) # here, we merge default :plus_poles.

          return task, local_options, options, sequence_options
        end
      end

    end # Builder
  end
end


