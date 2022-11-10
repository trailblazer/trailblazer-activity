module Trailblazer
  class Activity
    # In NodeAttributes we store data from Intermediate and Implementing compile-time.
    # This would be lost otherwise.
    NodeAttributes = Struct.new(:id, :outputs, :task, :data) # TODO: rename to Schema::Task::Attributes.

    # TODO: deprecate :nodes in favor of [brain/1]
    class Schema < Struct.new(:circuit, :outputs, :nodes, :config)

      # @!method to_h()
      #   Returns a hash containing the schema's components.

    end # Schema
  end
end
