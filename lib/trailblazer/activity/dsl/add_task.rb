class Trailblazer::Activity < Module
  module DSL
    module AddTask
      def add_task!(strategy, polarizer, name, task, options, &block)
        # The beautiful thing about State.add is it doesn't mutate anything.
        # We're changing state here, on the outside, by overriding the ivars.
        # That in turn means, the only mutated entity is this module.

        _builder, adds, circuit, outputs, options = Magnetic::Builder::State.add( self[:builder], self[:adds], strategy, polarizer, name, task, options, &block ) # this could be an extension itself.

        self[:adds]    = adds
        self[:circuit] = circuit
        self[:outputs] = outputs

        task, local_options = options

        # {Extension API} call all extensions.
        local_options[:extension].collect { |ext| ext.(self, *options) } if local_options[:extension]
      end
    end
  end
end
