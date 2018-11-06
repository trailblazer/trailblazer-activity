module Trailblazer
  class Activity::Magnetic::Builder
    # Maintain Builder instance plus Adds/Process/Outputs as immutable objects.
    module State
      def self.build(builder_class, normalizer, builder_options)
        builder, adds = builder_class.for(normalizer, builder_options) # e.g. Path.for(...) which creates a Builder::Path instance.

        recompile(builder.freeze, adds.freeze)
      end

      def self.add(builder, adds, strategy, polarizer, *args, &block)
        new_adds, *returned_options = builder.insert(strategy, polarizer, *args, &block) # TODO: move that out of here.

        adds = adds + new_adds

        recompile(builder, adds.freeze, returned_options)
      end

      private

      def self.recompile(builder, adds, *args)
        process = Finalizer.(adds)

        outputs_map = Hash[process.outputs.collect { |out| [out.semantic, out] }]

        return builder, adds, process, outputs_map, *args
      end
    end # State
  end
end
