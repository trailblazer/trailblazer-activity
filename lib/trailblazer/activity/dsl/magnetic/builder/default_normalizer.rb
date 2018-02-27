module Trailblazer
  module Activity::Magnetic
    # This normalizer only processes basic input and is meant for bootstrapping.
    #
    #   task Callable, id: "success", before: "another"
    class DefaultNormalizer
      # Declarative::Variables
      def self.build(plus_poles:, extension:[], **options)
        return new(plus_poles: plus_poles, extension: extension), options
      end

      def initialize(**default_options)
        @default_options = default_options
      end

      # Processes the user arguments from the DSL
      def call(task, options)
        local_options = @default_options.merge(options) # here, we merge default :plus_poles.

        local_options, sequence_options = Options.normalize( local_options, Activity::Schema::Dependencies.sequence_keywords )

        return task, local_options, {}, sequence_options
      end
    end
  end
end
