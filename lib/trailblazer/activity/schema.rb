module Trailblazer
  class Activity < Module
    NodeAttributes = Struct.new(:id, :outputs, :task, :data)

    # Schema is primitive data structure + an invoker (usually coming from Activity etc)
    class Schema < Struct.new(:circuit, :outputs, :nodes, :config)
    end # Schema
  end
end
