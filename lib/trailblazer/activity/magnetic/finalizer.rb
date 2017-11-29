module Trailblazer
  module Activity::Magnetic
    class Builder
      module Finalizer
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

          return Activity::Process.new( circuit_hash, end_events ), end_events
        end

        # Filters out unconnected ends, e.g. the standard end in nested tracks that weren't used.
        def self.end_events_for(circuit_hash)
          tasks_with_incoming_edge = circuit_hash.values.collect { |connections| connections.values }.flatten(1)

          ary = circuit_hash.collect do |task, connections|
            task.kind_of?(Circuit::End) &&
              connections.empty? &&
              tasks_with_incoming_edge.include?(task) ? [task, task.instance_variable_get(:@options)[:semantic]] : nil
          end

          ::Hash[ ary.compact ]
        end

        def self.call(adds)
          tripletts = adds_to_tripletts(adds)

          circuit_hash = tripletts_to_circuit_hash( tripletts )

          circuit_hash_to_process( circuit_hash )
        end
      end
    end
  end
end
