module Trailblazer
  class Activity < Module
    def self.Path(options={})
      Activity::Path.new(Path, options)
    end

    # Implementation module that can be passed to `Activity[]`.
    class Path < Activity
      # Default variables, called in {Activity::initialize}.
      def self.config
        {
          builder_class:    Magnetic::Builder::Path, # we use the Activity-based Normalizer
          normalizer_class: Magnetic::Normalizer,
          default_outputs:  Magnetic::Builder::Path.DefaultOutputs,
          extension:        [ Introspect.method(:add_introspection) ],

          extend:           [ DSL.def_dsl(:task) ],
        }
      end
    end # Path
  end
end

