module Trailblazer
  class Activity
    # This "circuit" is optimized for
    #   a) merging speed at run-time, since features like tracing will be applied here.
    #   b) execution speed. Every task in the real circuit is wrapped with one of us.
    #
    # It doesn't come with built-in insertion mechanics (except for {Pipeline.prepend}).
    # Please add/remove steps using the {Activity::Adds} methods.
    class Pipeline
      def initialize(sequence)
        @sequence = sequence # [[id, task], ..]
      end

      # Execute the pipeline and call all its steps, passing around the {wrap_ctx}.
      def call(wrap_ctx, original_args)
        @sequence.each { |(_id, task)| wrap_ctx, original_args = task.(wrap_ctx, original_args) }

        return wrap_ctx, original_args
      end

      # Comply with the Adds interface.
      def to_a
        @sequence
      end

      def self.Row(id, task)
        Row[id, task]
      end

      class Row < Array
        def id
          self[0]
        end
      end
    end

    def self.Pipeline(*args)
      Pipeline.new(*args)
    end

    # TODO: remove deprecation in 2.3.
    module TaskWrap
      class Pipeline
        def initialize(*args)
          Activity::Deprecate.warn caller_locations[0], "Using `TaskWrap::Pipeline.new()` is deprecated. Please use `Activity.Pipeline()`."

          Activity.Pipeline(*args)
        end

        def self.Row(*args)
          Activity::Deprecate.warn caller_locations[0], "Using `TaskWrap::Pipeline::Row()` is deprecated. Please use `Activity.Pipeline()`. XXXXXXXXXXXXXXXXXXXXXXXX # FIXME."

          Activity::Pipeline.Row(*args)
        end
      end
    end
  end
end
