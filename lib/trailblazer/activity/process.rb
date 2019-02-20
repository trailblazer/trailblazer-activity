module Trailblazer
  class Activity < Module
    NodeAttributes = Struct.new(:id, :outputs, :task, :data)

    # Process is primitive data structure + an invoker (usually coming from Activity etc)
    class Process < Struct.new(:circuit, :outputs, :nodes, :config)
    end # Process
  end
end
