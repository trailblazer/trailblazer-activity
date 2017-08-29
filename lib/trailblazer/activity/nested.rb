module Trailblazer
  class Activity
      # Builder for running a nested process from a specific `start_at` position.
    def self.Nested(*args, &block)
      Nested.new(*args, &block)
    end

    # Nested allows to have tasks with a different call interface and start event.
    # @param activity Activity interface
    class Nested
      def initialize(activity, start_at: nil, call: :call, &block)
        @activity, @start_at, @call, @block = activity, start_at, call, block
      end

      def call(start_at, *args)
        return @block.(activity: activity, start_at: @start_at, args: args) if @block

        @activity.public_send(@call, @start_at, *args)
      end

      # @private
      attr_reader :activity # we actually only need this for introspection.
    end
  end
end
