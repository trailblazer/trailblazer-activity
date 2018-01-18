module Trailblazer
  module Activity::Magnetic
    # The {Normalizer} is called for every DSL call (step/pass/fail etc.) and normalizes/defaults
    # the user options, such as setting `:id`, connecting the task's outputs or wrapping the user's
    # task via {TaskBuilder::Binary} in order to translate true/false to `Right` or `Left`.
    #
    # The Normalizer sits in the `@builder`, which receives all DSL calls from the Operation subclass.
    class Normalizer

      # @private Might be removed.
      def self.InitialPlusPoles
        Activity::Magnetic::DSL::PlusPoles.new.merge(
          Activity.Output(Activity::Right, :success) => nil,
          Activity.Output(Activity::Left,  :failure) => nil,
        )
      end

      def initialize(task_builder: Activity::TaskBuilder::Binary, default_plus_poles: Normalizer.InitialPlusPoles(), activity: Pipeline, **options)
        @task_builder       = task_builder
        @default_plus_poles = default_plus_poles
      end

      def call(task, options, unknown_options, sequence_options)
        ctx = {
          task: task, options: options, unknown_options: unknown_options, sequence_options: sequence_options,
          task_builder:       @task_builder,
          default_plus_poles: @default_plus_poles,
        }

        signal, (ctx, ) = Pipeline.( [ctx] )

        return ctx[:options][:task], ctx[:options], ctx[:unknown_options], ctx[:sequence_options]
      end

      # needs the basic Normalizer

      # :default_plus_poles is an injectable option.
      module Pipeline
        extend Activity[ Activity::Path, normalizer: Builder::DefaultNormalizer.new(plus_poles: Builder::Path.default_plus_poles) ]

        def self.normalize_extension_option( ctx, options:, ** )
          ctx[:options][:extension] = (options[:extension]||[]) + [ Activity::Introspect.method(:add_introspection) ] # fixme: this sucks
        end

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
        def self.defaultize( ctx, options:, default_plus_poles:, ** ) # TODO: test :default_plus_poles
          ctx[:options] =
            {
              plus_poles: default_plus_poles,
            }
            .merge(options)
        end

        task Activity::TaskBuilder::Binary.( method(:normalize_extension_option) )
        task Activity::TaskBuilder::Binary.( method(:normalize_for_macro) )
        task Activity::TaskBuilder::Binary.( method(:defaultize) )
      end
    end # Normalizer

  end
end
