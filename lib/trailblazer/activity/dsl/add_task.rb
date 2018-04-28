class Trailblazer::Activity < Module
  module DSL
    module AddTask
      def add_task!(strategy, polarizer, name, task, options, &block)
        # The beautiful thing about State.add is it doesn't mutate anything.
        # We're changing state here, on the outside, by overriding the ivars.
        # That in turn means, the only mutated entity is this module.

        _builder, adds, circuit, outputs, returned_options = Magnetic::Builder::State.add( self[:builder], self[:adds], strategy, polarizer, task, options, &block ) # this could be an extension itself.

        self[:adds]    = adds
        self[:circuit] = circuit
        self[:outputs] = outputs

        _, local_options, connections, sequence_options, extension_options = returned_options

        # {Extension API} call all extensions.
        extension_options.keys.collect { |ext| ext.( self, *returned_options, original_dsl_args: [name, task, options, block] ) }
      end
    end
  end
end
