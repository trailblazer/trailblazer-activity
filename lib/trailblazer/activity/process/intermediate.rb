class Trailblazer::Activity
  class Process
    class Intermediate < Struct.new(:wiring, :stop_task_refs, :start_tasks)
      # Intermediate structures
      TaskRef = Struct.new(:id, :data) # TODO: rename to NodeRef
      Out     = Struct.new(:semantic, :target)

      def self.TaskRef(id, data={}); TaskRef.new(id, data) end
      def self.Out(*args);           Out.new(*args)        end

      # Compiles a {Process} instance from an {intermediate} structure and
      # the {implementation} object references.
      def self.call(intermediate, implementation)
        circuit = circuit(intermediate, implementation)
        nodes   = node_attributes(implementation)
        outputs = outputs(intermediate.stop_task_refs, nodes)
        process = Process.new(circuit, outputs, nodes)
      end

      # From the intermediate "template" and the actual implementation, compile a {Circuit} instance.
      def self.circuit(intermediate, implementation)
        wiring = Hash[
          intermediate.wiring.collect do |task_ref, outs|
            task = implementation.fetch(task_ref.id)

            [
              task.circuit_task,
              Hash[ # compute the connections for {circuit_task}.
                outs.collect { |required_out|
                  [
                    for_semantic(task.outputs, required_out.semantic).signal,
                    implementation.fetch(required_out.target).circuit_task
                  ]
                }
              ]
            ]
          end
        ]

        Circuit.new(
          wiring,
          intermediate.stop_task_refs.collect { |task_ref| implementation.fetch(task_ref.id).circuit_task },
          start_task: intermediate.start_tasks.collect { |task_ref| implementation.fetch(task_ref.id).circuit_task }[0]
        )
      end

      # DISCUSS: this is intermediate-independent?
      def self.node_attributes(implementation, nodes_data={}) # TODO: process {nodes_data}
        implementation.collect do |id, task| # id, Task{circuit_task, outputs}
          NodeAttributes.new(id, task.outputs, task.circuit_task, {})
        end
      end

      # intermediate/implementation independent.
      def self.outputs(stop_task_refs, nodes_attributes)
        stop_task_refs.collect do |task_ref|
          # Grab the {outputs} of the stop nodes.
          nodes_attributes.find { |node_attrs| task_ref.id == node_attrs.id }.outputs
        end.flatten(1)
      end

      private

      # Apply to any array.
      def self.for_semantic(ary, semantic)
        ary.find { |out| out.semantic == semantic } or raise "`#{semantic}` not found"
      end
    end # Intermediate
  end
end
