class Trailblazer::Activity < Module
  def self.FastTrack(options={})
    FastTrack.new(FastTrack, options)
  end

  # Implementation module that can be passed to `Activity[]`.
  class FastTrack < Trailblazer::Activity
    def self.config
      Railway.config.merge(
        builder_class:  Magnetic::Builder::FastTrack,
      )
    end
  end
end
