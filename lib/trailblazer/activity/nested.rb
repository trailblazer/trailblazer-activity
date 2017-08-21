module Trailblazer
  class Activity
      # Builder for running a nested process from a specific `start_at` position.
    def self.Nested(*args, &block)
      Nested.new(*args, &block)
    end

    # Nested allows to have tasks with a different call interface and start event.
    # @param activity Activity interface
    class Nested
      def initialize(activity, start_with=nil, &block)
        @activity, @start_with, @block = activity, start_with, block
      end

      def call(start_at, *args)
        return @block.(activity: activity, start_at: @start_with, args: args) if @block

        @activity.(@start_with, *args)
      end

      # @private
      attr_reader :activity # we actually only need this for introspection.
    end
  end
end
