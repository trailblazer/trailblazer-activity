module Trailblazer
  class Activity
    # This "circuit" is optimized for
    #   a) merging speed at run-time, since features like tracing will be applied here.
    #   b) execution speed. Every task in the real circuit is wrapped with one of us.
    # TODO: better docs here, it's a special {circuit}.
    #
    # It doesn't come with built-in insertion mechanics (except for {Pipeline.prepend}).
    # Please add/remove steps using the {Activity::Adds} methods.
    class Pipeline
      def initialize(sequence)
        @sequence = sequence # [[id, task], ..]
      end

      # Execute the pipeline and call all its steps, passing around the {wrap_ctx}.
      def call(wrap_ctx, flow_options, circuit_options = {})
        # DISCUSS: to be completely consistent, we should be using a runner to invoke the task here.
        @sequence.each do |(_id, task)|
          wrap_ctx, flow_options = task.(wrap_ctx, flow_options, circuit_options)
        end

        return wrap_ctx, flow_options
      end

      # FIXME: experimental.
      # FIXME: experimenting with a Pipeline#call behavior plus Runner, like a Circuit.
      def self.call(pipeline, ctx, flow_options, circuit_options = {})
        runner = circuit_options[:runner]

        pipeline.to_a.each do |(_id, task)|
          ctx, flow_options = runner.(task, ctx, flow_options, circuit_options)
        end

        return ctx, flow_options # FIXME: experimenting here.
      end

      # TODO: this should be @private as users should only use #collect outside?
      # @private
      def to_a
        @sequence
      end

      def to_h
        @sequence.to_h
      end

      # @semi-private
      # DISCUSS: do we want to keep this? used in many places across dsl.
      # This method exists to, obviously, hide internals about the structure.
      # this is a "decorator method".
      def self.find(sequence, id:)
        _, row = sequence.to_a.find { |row_id, _| row_id == id }

        row
      end
    end

    def self.Pipeline(hsh)
      Pipeline.new(hsh.to_a)
    end

    # TODO: remove deprecation in 2.3.
    # TODO: test deprecations.
    module TaskWrap
      class Pipeline
        def initialize(*args)
          Activity::Deprecate.warn caller_locations[0], "Using `TaskWrap::Pipeline.new()` is deprecated. Please use `Activity.Pipeline()`."

          Activity.Pipeline(*args)
        end

        def self.Row(id, task)
          Activity::Deprecate.warn caller_locations[0], "Using `TaskWrap::Pipeline::Row()` is deprecated. Please use `Activity.Pipeline()`. XXXXXXXXXXXXXXXXXXXXXXXX # FIXME."

          [id, task]
        end
      end
    end
  end
end
