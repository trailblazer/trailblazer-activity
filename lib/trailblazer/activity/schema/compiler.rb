module Trailblazer
  class Activity
    class Schema
      class Intermediate
        module Compiler
          module_function

          DEFAULT_CONFIG = {wrap_static: Hash.new(Activity::TaskWrap.initial_wrap_static.freeze)} # DISCUSS: this really doesn't have to be here, but works for now and we want it in 99%.

          # Compiles a {Schema} instance from an {intermediate} structure and
          # the {implementation} object references.
          #
          # Intermediate structure, Implementation, calls extensions, passes {config} # TODO
          def call(intermediate, implementation, config_merge: {})
            config = DEFAULT_CONFIG
              .merge(config_merge)
              .freeze

            circuit, outputs, nodes, config = schema_components(intermediate, implementation, config)

            Schema.new(circuit, outputs, nodes, config)
          end

          # From the intermediate "template" and the actual implementation, compile a {Circuit} instance.
          def schema_components(intermediate, implementation, config)
            wiring = {}
            nodes_attributes  = []

            intermediate.wiring.each do |task_ref, outs|
              id        = task_ref.id
              impl_task = implementation.fetch(id)
              task      = impl_task.circuit_task
              outputs   = impl_task.outputs

              wiring[task] = connections_for(outs, outputs, implementation)

              nodes_attributes << [
                id,               # id
                task,             # task
                task_ref[:data],  # TODO: allow adding data from implementation.
                outputs           # {Activity::Output}s
              ]

              # Invoke each task's extensions (usually coming from the DSL user or some macro).
              # We're expecting each {ext} to be a {TaskWrap::Extension::WrapStatic} instance.
              config = invoke_extensions_for(config, impl_task, id)
            end

            start_id = intermediate.start_task_id

            terminus_to_output  = terminus_to_output(intermediate, implementation)
            activity_outputs    = terminus_to_output.values

            circuit = Circuit.new(
              wiring,
              terminus_to_output.keys, # termini
              start_task: implementation.fetch(start_id).circuit_task
            )

            return circuit,
              activity_outputs,
              Schema::Nodes(nodes_attributes),
              config
          end

          # Compute the connections for {circuit_task}.
          # For a terminus, this produces an empty hash.
          def connections_for(intermediate_outs, task_outputs, implementation)
            intermediate_outs.collect { |intermediate_out| # Intermediate::Out, it's abstract.
              [
                output_for_semantic(task_outputs, intermediate_out.semantic).signal,
                implementation.fetch(intermediate_out.target).circuit_task    # Find the implementation task, the Ruby code component for runtime.
              ]
            }.to_h
          end

          def terminus_to_output(intermediate, implementation)
            terminus_to_semantic = intermediate.stop_task_ids

            terminus_to_semantic.collect do |id, semantic|
              terminus_task = implementation.fetch(id).circuit_task

              [
                terminus_task,
                Activity::Output(terminus_task, semantic) # The End instance is the signal.
              ]
            end.to_h
          end

          # Run all Implementation::Task.extensions and return new {config}
          def invoke_extensions_for(config, impl_task, id)
            impl_task
              .extensions
              .inject(config) { |cfg, ext| ext.(config: cfg, id: id, task: impl_task) } # {ext} must return new config hash.
          end

          # In an array of {Activity::Output}, find the output matching {semantic}.
          def output_for_semantic(outputs, semantic)
            outputs.find { |out| out.semantic == semantic } or raise "`#{semantic}` not found in implementation"
          end
        end # Intermediate
      end
    end
  end
end
