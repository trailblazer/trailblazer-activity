module Trailblazer
  module Activity::Magnetic
    class DefaultNormalizer
      # Declarative::Variables
      def self.build(plus_poles:, extension:[], **options)
        return new(plus_poles: plus_poles, extension: extension), options
      end

      def initialize(**default_options)
        @default_options = default_options
      end

      # called for every ::task, ::step call etc to defaultize the `local_options`.
      def call(task, local_options, options, sequence_options)
        local_options = local_options.merge(extension: @default_options[:extension]+(local_options[:extension]||[]) ) # FIXME.

        local_options = @default_options.merge(local_options) # here, we merge default :plus_poles.

        return task, local_options, options, sequence_options
      end
    end
  end
end
