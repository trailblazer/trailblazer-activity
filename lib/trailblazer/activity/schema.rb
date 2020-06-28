module Trailblazer
  class Activity
    NodeAttributes = Struct.new(:id, :outputs, :task, :data)

    # Schema is primitive data structure + an invoker (usually coming from Activity etc)
    class Schema < Struct.new(:circuit, :outputs, :nodes, :config)

      # @!method to_h()
      #   Returns a hash containing the schema's components.

    end # Schema
  end
end
require "trailblazer/activity/schema/implementation"
require "trailblazer/activity/schema/intermediate"
