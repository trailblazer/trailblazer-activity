class Trailblazer::Activity
  class Process
    module Implementation
      # Implementation structures
      Task = Struct.new(:circuit_task, :outputs)

      def self.Task(*args); Task.new(*args) end
    end
  end
end
