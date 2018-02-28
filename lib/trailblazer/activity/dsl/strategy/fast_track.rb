class Trailblazer::Activity < Module
  def self.FastTrack(options={})
    FastTrack.new(FastTrack, options)
  end

  # Implementation module that can be passed to `Activity[]`.
  class FastTrack < Trailblazer::Activity
    def self.config
      Railway.config.merge(
        builder_class:  Magnetic::Builder::FastTrack,
        extend:          [
          DSL.def_dsl(:step, Magnetic::Builder::FastTrack, :StepPolarizations),
          DSL.def_dsl(:fail, Magnetic::Builder::FastTrack, :FailPolarizations),
          DSL.def_dsl(:pass, Magnetic::Builder::FastTrack, :PassPolarizations)
        ],
      )
    end
  end
end