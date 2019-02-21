class Trailblazer::Activity
  class Schema
    module Implementation
      # Implementation structures
      Task = Struct.new(:circuit_task, :outputs, :extensions)

      def self.Task(task, outputs, extensions=[]); Task.new(task, outputs, extensions) end
    end
  end
end
