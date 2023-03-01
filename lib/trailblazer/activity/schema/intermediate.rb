class Trailblazer::Activity
  class Schema
    # An {Intermediate} structure defines the *structure* of the circuit. It usually
    # comes from a DSL or a visual editor.
    class Intermediate < Struct.new(:wiring, :stop_task_ids, :start_task_id)
      TaskRef = Struct.new(:id, :data) # TODO: rename to NodeRef
      Out     = Struct.new(:semantic, :target)

      def self.TaskRef(id, data = {})
        TaskRef.new(id, data)
      end

      def self.Out(*args)
        Out.new(*args)
      end
    end # Intermediate
  end
end
