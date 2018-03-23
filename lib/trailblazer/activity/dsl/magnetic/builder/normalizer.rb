module Trailblazer
  module Activity::Magnetic
    # One {Normalizer} instance is called for every DSL call (step/pass/fail etc.) and normalizes/defaults
    # the user options, such as setting `:id`, connecting the task's outputs or wrapping the user's
    # task via {TaskBuilder::Binary} in order to translate true/false to `Right` or `Left`.
    #
    # The Normalizer sits in the `@builder`, which receives all DSL calls from the Operation subclass.
    class Normalizer
      def self.build(task_builder: Activity::TaskBuilder.method(:Binary), default_outputs: Builder::Path.default_outputs, pipeline: Pipeline, extension:[], **options)
        return new(
          default_outputs: default_outputs,
          extension:       extension,
          task_builder:    task_builder,
          pipeline:        pipeline,
        ), options
      end

      def initialize(task_builder:, default_outputs:, pipeline:, **options)
        @task_builder    = task_builder
        @default_outputs = default_outputs
        @pipeline        = pipeline # TODO: test me.
        freeze
      end

      def call(task, options)
        ctx = {
          task:            task,
          options:         options,
          task_builder:    @task_builder,
          default_outputs: @default_outputs,
        }

        signal, (ctx, ) = @pipeline.( [ctx] )

        return ctx[:options][:task], ctx[:local_options], ctx[:connection_options], ctx[:sequence_options]
      end

      # needs the basic Normalizer

      # :default_plus_poles is an injectable option.
      module Pipeline
        extend Trailblazer::Activity::Path( normalizer_class: DefaultNormalizer, plus_poles: PlusPoles.new.merge( Builder::Path.default_outputs.values ) ) # FIXME: the DefaultNormalizer actually doesn't need Left.

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
        def self.extract_dsl_keywords(options, connection_classes = [Activity::Output, Activity::DSL::OutputSemantic])
          options.keys - options.keys.find_all { |k| connection_classes.include?( k.class ) }
        end

        # FIXME; why don't we use the extensions passed into the initializer?
        def self.normalize_extension_option( ctx, local_options:, ** )
          local_options[:extension] = (local_options[:extension]||[]) + [ Activity::Introspect.method(:add_introspection), Activity::DSL.method(:record) ] # fixme: this sucks
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

        # :outputs passed: I know what I want to have connected.
        # no :outputs: use default_outputs
        # ALWAYS connect all outputs to their semantic-color.

        # Create the `plus_poles: <PlusPoles>` tuple where the PlusPoles instance will act as the interface
        # to rewire or add connections for the DSL.
        def self.initialize_plus_poles( ctx, local_options:, default_outputs:, ** )
          outputs = local_options[:outputs] || default_outputs

          ctx[:local_options] =
            {
              plus_poles: PlusPoles.initial(outputs),
            }
            .merge(local_options)
        end

        task Activity::TaskBuilder::Binary( method(:normalize_for_macro) ),        id: "normalize_for_macro"
        task Activity::TaskBuilder::Binary( method(:split_options) ),              id: "split_options"
        task Activity::TaskBuilder::Binary( method(:normalize_extension_option) ), id: "normalize_extension_option"
        task Activity::TaskBuilder::Binary( method(:initialize_plus_poles) ),      id: "initialize_plus_poles"
        # task ->((ctx, _), **) { pp ctx; [Activity::Right, [ctx, _]] }
      end
    end # Normalizer

  end
end
