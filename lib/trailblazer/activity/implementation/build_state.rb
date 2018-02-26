class Trailblazer::Activity < Module
  module BuildState
    # Compute all objects that need to be passed into the new Activity module.
    # 1. Build the normalizer (unless passed with :normalizer)
    # 2. Build the builder (in State)
    # 3. Let State compute all state variables (that implies recompiling the Process)
    #
    # @return [Builder, Adds, Process, Outputs, remaining options]
    # @api private
    def self.build_state_for(default_options, options)
      options                                  = default_options.merge(options) # TODO: use Variables::Merge() here.
      normalizer, options                      = build_normalizer(options)
      builder, adds, circuit, outputs, options = build_state(normalizer, options)
    end

    # Builds the normalizer (to process options in DSL calls) unless {:normalizer} is already set.
    #
    # @api private
    def self.build_normalizer(normalizer_class:, normalizer: false, **options)
      normalizer, options = normalizer_class.build( options ) unless normalizer

      return normalizer, options
    end

    # @api private
    def self.build_state(normalizer, builder_class:, builder_options: {}, **options)
      builder, adds, circuit, outputs = Magnetic::Builder::State.build(builder_class, normalizer, options.merge(builder_options))

      return builder, adds, circuit, outputs, options
    end
  end
end
