class Trailblazer::Activity
  class Schema
    # @private This class might get removed in 0.17.0.
    module Implementation
      # Implementation structures
      Task = Struct.new(:circuit_task, :outputs, :extensions)

      def self.Task(task, outputs, extensions = [])
        Task.new(task, outputs, extensions)
      end
    end
  end
end
