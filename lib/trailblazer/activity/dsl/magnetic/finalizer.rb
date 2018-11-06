module Trailblazer
  module Activity::Magnetic
    class Builder
      module Finalizer
        def self.call(adds)
          tripletts, node_configurations = adds_to_tripletts(adds)

          circuit_hash = tripletts_to_circuit_hash( tripletts )

          circuit, end_events = circuit_hash_to_process( circuit_hash )

          outputs = recompile_outputs(end_events)

          return Process.new(circuit, outputs, node_configurations).freeze
        end

        def self.recompile_outputs(end_events)
          end_events.collect do |evt|
            Activity::Output(evt, evt.to_h[:semantic])
          end
        end

        def self.adds_to_tripletts(adds)
          alterations = adds_to_alterations(adds)

          node_configurations = alterations_to_node_configurations(alterations)

          return alterations.to_a, node_configurations
        end

        NodeConfiguration = Struct.new(:id, :outputs, :task, :data)
        Process = Struct.new(:circuit, :outputs, :nodes)

        # FIXME: this is a bit of a hack until the DSL code got simplified.
        def self.alterations_to_node_configurations(alterations)
          alterations.instance_variable_get(:@groups).instance_variable_get(:@groups).collect do |_, group|
            group.collect do |element|
              _, task, plus_poles = element.configuration

              NodeConfiguration.new(element.id, plus_poles.collect { |pole| pole.send(:output) }, task )
            end
          end.flatten(1)
        end

        def self.adds_to_alterations(adds)
          alterations = DSL::Alterations.new

          adds = adds.compact # TODO: test me explicitly, and where does this come from anyway?

          adds.each { |method, cfg| alterations.send( method, *cfg ) }

          alterations
        end

        def self.tripletts_to_circuit_hash(tripletts)
          Activity::Magnetic::Generate.( tripletts )
        end

        def self.circuit_hash_to_process(circuit_hash)
          end_events = end_events_for(circuit_hash)

          return Circuit.new(circuit_hash, end_events, start_task: circuit_hash.keys.first), end_events
        end

        # Find all end events that don't have outgoing connections.
        def self.end_events_for(circuit_hash)
          ary = circuit_hash.collect do |task, connections|
            task.kind_of?(Activity::End) && connections.empty? ? task : nil
          end

          ary.compact
        end
      end
    end
  end
end
