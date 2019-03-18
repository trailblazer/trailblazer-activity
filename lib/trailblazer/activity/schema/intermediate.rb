class Trailblazer::Activity
  class Schema
    class Intermediate < Struct.new(:wiring, :stop_task_ids, :start_task_ids)
      # Intermediate structures
      TaskRef = Struct.new(:id, :data) # TODO: rename to NodeRef
      Out     = Struct.new(:semantic, :target)

      def self.TaskRef(id, data={}); TaskRef.new(id, data) end
      def self.Out(*args);           Out.new(*args)        end

      # Compiles a {Schema} instance from an {intermediate} structure and
      # the {implementation} object references.
      #
      # Intermediate structure, Implementation, calls extensions, passes {}config # TODO
      def self.call(intermediate, implementation)
        config_default = {wrap_static: Hash.new(TaskWrap.initial_wrap_static)}.freeze # DISCUSS: this really doesn't have to be here, but works for now and we want it in 99%.

        circuit = circuit(intermediate, implementation)
        nodes   = node_attributes(intermediate, implementation)
        outputs = outputs(intermediate.stop_task_ids, nodes)
        config  = config(implementation, config: config_default)
        schema  = Schema.new(circuit, outputs, nodes, config)
      end

      # From the intermediate "template" and the actual implementation, compile a {Circuit} instance.
      def self.circuit(intermediate, implementation)
        wiring = Hash[
          intermediate.wiring.collect do |task_ref, outs|
            task = implementation.fetch(task_ref.id)

            [
              task.circuit_task,
              task_ref.data[:stop_event] ? {} : connections_for(outs, task.outputs, implementation)
            ]
          end
        ]

        Circuit.new(
          wiring,
          intermediate.stop_task_ids.collect { |id| implementation.fetch(id).circuit_task },
          start_task: intermediate.start_task_ids.collect { |id| implementation.fetch(id).circuit_task }[0]
        )
      end

      # Compute the connections for {circuit_task}.
      def self.connections_for(outs, task_outputs, implementation)
        Hash[
          outs.collect { |required_out|
            [
              for_semantic(task_outputs, required_out.semantic).signal,
              implementation.fetch(required_out.target).circuit_task
            ]
          }.compact
        ]
      end

      def self.node_attributes(intermediate, implementation)
        intermediate.wiring.collect do |task_ref, outputs| # id, Task{circuit_task, outputs}
          task = implementation.fetch(task_ref.id)
          data = task_ref[:data] # TODO: allow adding data from implementation.

          NodeAttributes.new(task_ref.id, task.outputs, task.circuit_task, data)
        end
      end

      # intermediate/implementation independent.
      def self.outputs(stop_task_ids, nodes_attributes)
        stop_task_ids.collect do |id|
          # Grab the {outputs} of the stop nodes.
          nodes_attributes.find { |node_attrs| id == node_attrs.id }.outputs
        end.flatten(1)
      end

      # Invoke each task's extensions (usually coming from the DSL or some macro).
      def self.config(implementation, config:)
        implementation.each do |id, task|
          task.extensions.each { |ext| config = ext.(config: config, id: id, task: task) } # DISCUSS: ext must return new {Config}.
        end

        config
      end

      private

      # Apply to any array.
      def self.for_semantic(outputs, semantic)
        outputs.find { |out| out.semantic == semantic } or raise "`#{semantic}` not found"
      end
    end # Intermediate
  end
end
