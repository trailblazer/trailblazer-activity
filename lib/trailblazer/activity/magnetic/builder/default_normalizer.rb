module Trailblazer
  module Activity::Magnetic
    class Builder
      class DefaultNormalizer
        # Declarative::Variables

        def initialize(**default_options)
          raise "you didn't specify default :plus_poles" unless default_options[:plus_poles]

          @default_options = default_options
        end

        # called for every ::task, ::step call etc to defaultize the `local_options`.
        def call(task, local_options, options, sequence_options)
          local_options = local_options.merge(extension: (@default_options[:extension]||[])+(local_options[:extension]||[]) ) # FIXME.

          local_options = @default_options.merge(local_options) # here, we merge default :plus_poles.

          return task, local_options, options, sequence_options
        end
      end
    end
  end
end
