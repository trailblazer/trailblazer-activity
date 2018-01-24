module Trailblazer
  class Activity < Module   # @private
    # Maintain Builder/Adds/Process/Outputs as immutable objects.
    module State
      def self.build(builder_class, normalizer, builder_options)
        builder, adds = builder_class.for(normalizer, builder_options) # e.g. Path.for(...) which creates a Builder::Path instance.

        recompile(builder.freeze, adds.freeze)
      end

      def self.add(builder, adds, name, *args, &block)
        new_adds, *returned_options = builder.insert(name, *args, &block) # builder.task

        adds = adds + new_adds

        recompile(builder, adds.freeze, returned_options)
      end

      private

      # @return {builder, Adds, Process, outputs}, returned_options
      def self.recompile(builder, adds, *args)
        circuit, outputs = recompile_circuit(adds)

        return builder, adds, circuit.freeze, outputs.freeze, *args
      end

      def self.recompile_circuit(adds)
        circuit, outputs = Recompile.( adds )
      end

      module Recompile
        # Recompile the circuit and outputs from the {ADDS} instance that collects circuit tasks and connections.
        #
        # @return [Process, Hash] The {Process} instance and its outputs hash.
        def self.call(adds)
          circuit, end_events = Magnetic::Builder::Finalizer.(adds)
          outputs             = recompile_outputs(end_events)

          return circuit, outputs
        end

        private

        def self.recompile_outputs(end_events)
          ary = end_events.collect do |evt|
            [
              semantic = evt.to_h[:semantic],
              Activity::Output(evt, semantic)
            ]
          end

          ::Hash[ ary ]
        end
      end # Recompile
    end # State
  end
end
