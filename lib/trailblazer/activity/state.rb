module Trailblazer
  module Activity    # @private
    # Maintain Builder/Adds/Process/Outputs as immutable objects.
    module State
      def self.build(builder_class, normalizer, builder_options)
        builder, adds = builder_class.for(normalizer, builder_options) # e.g. Path.for(...) which creates a Builder::Path instance.

        recompile(builder.freeze, adds.freeze)
      end

      def self.add(builder, adds, name, *args, &block)
        new_adds, *returned_options = builder.send(name, *args, &block) # builder.task

        adds = adds + new_adds

        recompile(builder, adds.freeze, returned_options)
      end

      private


# def Builder.build(options={}, &block)
#   adds = plan( options, &block )

#   Finalizer.(adds)
# end

      # @return {builder, Adds, Process, outputs}, returned_options
      def self.recompile(builder, adds, *args)
        return builder, adds, *recompile_process(adds), *args
      end

      def self.recompile_process(adds)
        process, outputs = Recompile.( adds )
      end

      module Recompile
        # Recompile the process and outputs from the {ADDS} instance that collects circuit tasks and connections.
        #
        # @return [Process, Hash] The {Process} instance and its outputs hash.
        def self.call(adds)
          process, end_events = Magnetic::Builder::Finalizer.(adds)
          outputs             = recompile_outputs(end_events)

          return process, outputs
        end

        private

        def self.recompile_outputs(end_events)
          ary = end_events.collect do |evt|
            [
              semantic = evt.instance_variable_get(:@options)[:semantic], # DISCUSS: better API here?
              Activity::Output(evt, semantic)
            ]
          end

          ::Hash[ ary ]
        end
      end # Recompile
    end # State
  end
end
