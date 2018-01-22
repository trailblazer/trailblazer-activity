class Trailblazer::Activity < Module
  # Implementation module that can be passed to `Activity[]`.
  module FastTrack
    def self.config
      Railway.config.merge(
        builder_class:  Magnetic::Builder::FastTrack,
      )
    end

    # @import FastTrack::build_state_for
    extend BuildState
    # @import =>FastTrack#call
    include PublicAPI

    include DSL.def_dsl(:step)
    include DSL.def_dsl(:fail)
    include DSL.def_dsl(:pass)
  end
end
