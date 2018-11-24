module Trailblazer
  class Activity < Module
    NodeAttributes = Struct.new(:id, :outputs, :task, :data)

    class Process < Struct.new(:circuit, :outputs, :nodes)
    end # Process
  end
end
