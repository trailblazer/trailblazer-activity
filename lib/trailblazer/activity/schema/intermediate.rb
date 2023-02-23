class Trailblazer::Activity
  class Schema
    # An {Intermediate} structure defines the *structure* of the circuit. It usually
    # comes from a DSL or a visual editor.
    class Intermediate < Struct.new(:wiring, :stop_task_ids, :start_task_ids)
      TaskRef = Struct.new(:id, :data) # TODO: rename to NodeRef
      Out     = Struct.new(:semantic, :target)

      def self.TaskRef(id, data={}); TaskRef.new(id, data) end
      def self.Out(*args);           Out.new(*args)        end

      # Compiles a {Schema} instance from an {intermediate} structure and
      # the {implementation} object references.
      #
      # Intermediate structure, Implementation, calls extensions, passes {config} # TODO
      def self.call(intermediate, implementation, config_merge: {})
        config_default = {wrap_static: Hash.new(TaskWrap.initial_wrap_static)} # DISCUSS: this really doesn't have to be here, but works for now and we want it in 99%.
        config         = config_default.merge(config_merge)
        config.freeze

        circuit = circuit(intermediate, implementation)
        nodes   = nodes(intermediate, implementation) # TODO: build Schema::Nodes<[] structure Nodes#find_by_id. Nodes[task]. Remove TaskMap, we don't need it anymore.
        outputs = outputs(intermediate.stop_task_ids, nodes)
        config  = config(implementation, config: config)

        Schema.new(circuit, outputs, nodes, config)
      end

      # From the intermediate "template" and the actual implementation, compile a {Circuit} instance.
      def self.circuit(intermediate, implementation)
        end_events = intermediate.stop_task_ids

        wiring = Hash[
          intermediate.wiring.collect do |task_ref, outs|
            task = implementation.fetch(task_ref.id)

            [
              task.circuit_task,
              end_events.include?(task_ref.id) ? {} : connections_for(outs, task.outputs, implementation)
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
          outs.collect { |required_out| # Intermediate::Out, it's abstract.
            [
              for_semantic(task_outputs, required_out.semantic).signal,
              implementation.fetch(required_out.target).circuit_task
            ]
          }.compact
        ]
      end

      # Compile the Schema{:nodes} field.
      def self.nodes(intermediate, implementation)
        nodes_attributes =
          intermediate.wiring.collect do |task_ref, outputs|
            id                  = task_ref.id
            implementation_task = implementation.fetch(id)

            [
              id,                               # id
              implementation_task.outputs,      # outputs
              implementation_task.circuit_task, # task
              task_ref[:data]                   # TODO: allow adding data from implementation.
            ]
          end

        Schema::Nodes(nodes_attributes)
      end

      # intermediate/implementation independent.
      def self.outputs(stop_task_ids, nodes)
        stop_task_ids.collect do |id|
          # Grab the {outputs} of the stop nodes.
          Introspect::Nodes.find_by_id(nodes, id).outputs
        end.flatten(1)
      end

      # Invoke each task's extensions (usually coming from the DSL user or some macro).
      # We're expecting each {ext} to be a {TaskWrap::Extension::WrapStatic} instance.
      def self.config(implementation, config:)
        implementation.each do |id, task|
          task.extensions.each { |ext| config = ext.(config: config, id: id, task: task) } # DISCUSS: ext must return new {Config}.
        end

        config
      end



      # Apply to any array.
      private_class_method def self.for_semantic(outputs, semantic)
        outputs.find { |out| out.semantic == semantic } or raise "`#{semantic}` not found"
      end
    end # Intermediate
  end
end
