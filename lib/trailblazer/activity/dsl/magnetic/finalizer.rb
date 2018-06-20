module Trailblazer
  module Activity::Magnetic
    class Builder
      module Finalizer
        def self.call(adds)
          tripletts = adds_to_tripletts(adds)

          circuit_hash = tripletts_to_circuit_hash( tripletts )

          circuit_hash_to_process( circuit_hash )
        end

        def self.adds_to_tripletts(adds)
          alterations = adds_to_alterations(adds)

          alterations.to_a
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
