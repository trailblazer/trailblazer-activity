module Trailblazer::Activity
  # Implementation module that can be passed to `Activity[]`.
  module Railway
    def self.config
      Path.config.merge(
        builder_class:  Magnetic::Builder::Railway,
        plus_poles:     Magnetic::Builder::Railway.default_plus_poles
      )
    end

    # @import FastTrack::build_state_for
    extend BuildState
    # @import =>Railway#call
    include PublicAPI

    include DSL.def_dsl(:step)
    include DSL.def_dsl(:fail)
    include DSL.def_dsl(:pass)
  end
end
