module Trailblazer
  class Activity < Module
    Process        = Struct.new(:circuit, :outputs, :nodes)
    NodeAttributes = Struct.new(:id, :outputs, :task, :data)
  end
end
