module Trailblazer
  module Activity::Magnetic
    # The {Normalizer} is called for every DSL call (step/pass/fail etc.) and normalizes/defaults
    # the user options, such as setting `:id`, connecting the task's outputs or wrapping the user's
    # task via {TaskBuilder::Binary} in order to translate true/false to `Right` or `Left`.
    #
    # The Normalizer sits in the `@builder`, which receives all DSL calls from the Operation subclass.
    class Normalizer
      def self.build(task_builder: Activity::TaskBuilder::Binary, default_plus_poles: Normalizer.InitialPlusPoles(), pipeline: Pipeline, extension:[], **options)
        return new(
          default_plus_poles: default_plus_poles,
          extension:          extension,
          task_builder:       task_builder,
          pipeline:           pipeline,
        ), options
      end

      # @private Might be removed.
      def self.InitialPlusPoles
        Activity::Magnetic::DSL::PlusPoles.new.merge(
          Activity.Output(Activity::Right, :success) => nil,
          Activity.Output(Activity::Left,  :failure) => nil,
        )
      end

      def initialize(task_builder:, default_plus_poles:, pipeline:, **options)
        @task_builder       = task_builder
        @default_plus_poles = default_plus_poles
        @pipeline           = pipeline # TODO: test me.
      end

      def call(task, options)
        ctx = {
          task: task, options:  options,
          task_builder:         @task_builder,
          default_plus_poles:   @default_plus_poles,
        }

        signal, (ctx, ) = @pipeline.( [ctx] )

        return ctx[:options][:task], ctx[:local_options], ctx[:connection_options], ctx[:sequence_options]
      end

      # needs the basic Normalizer

      # :default_plus_poles is an injectable option.
      module Pipeline
        extend Activity[ Activity::Path, normalizer_class: DefaultNormalizer, plus_poles: Builder::Path.default_plus_poles ]

        def self.split_options( ctx, task:, options:, ** )
          keywords = extract_dsl_keywords(options)

           # sort through the "original" user DSL options.
          options, local_options          = Options.normalize( options, keywords ) # DISCUSS:
          local_options, sequence_options = Options.normalize( local_options, Activity::Schema::Dependencies.sequence_keywords )

          ctx[:local_options],
          ctx[:connection_options],
          ctx[:sequence_options] = local_options, options, sequence_options
        end

        # Filter out connections, e.g. `Output(:fail_fast) => :success` and return only the keywords like `:id` or `:replace`.
        def self.extract_dsl_keywords(options, connection_classes = [Activity::Output, DSL::Output::Semantic])
          options.keys - options.keys.find_all { |k| connection_classes.include?( k.class ) }
        end

        # FIXME; why don't we use the extensions passed into the initializer?
        def self.normalize_extension_option( ctx, local_options:, ** )
          local_options[:extension] = (local_options[:extension]||[]) + [ Activity::Introspect.method(:add_introspection) ] # fixme: this sucks
        end

        # Normalizes ctx[:options]
        def self.normalize_for_macro( ctx, task:, options:, task_builder:, ** )
          ctx[:options] =
            if task.is_a?(::Hash) # macro.
              options = options.merge(extension: (options[:extension]||[])+(task[:extension]||[]) ) # FIXME.

              task.merge(options) # Note that the user options are merged over the macro options.
            else # user step
              { id: task }
                .merge(options)                     # default :id
                .merge( task: task_builder.(task) )
            end
        end

        # Merge user options over defaults.
        def self.defaultize( ctx, local_options:, default_plus_poles:, ** ) # TODO: test :default_plus_poles
          ctx[:local_options] =
            {
              plus_poles: default_plus_poles,
            }
            .merge(local_options)
        end

        task Activity::TaskBuilder::Binary.( method(:normalize_for_macro) ),        id: "normalize_for_macro"
        task Activity::TaskBuilder::Binary.( method(:split_options) ),              id: "split_options"
        task Activity::TaskBuilder::Binary.( method(:normalize_extension_option) ), id: "normalize_extension_option"
        task Activity::TaskBuilder::Binary.( method(:defaultize) ),                 id: "defaultize"
        # task ->((ctx, _), **) { pp ctx; [Activity::Right, [ctx, _]] }
      end
    end # Normalizer

  end
end
