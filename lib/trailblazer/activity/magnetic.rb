module Trailblazer
  class Activity
    module Magnetic
      # all code related to the magnetic building of a circuit hash lives in this namespace.
    end

    def self.plan(options={}, &block)
      Magnetic::Path::Builder.plan(options, &block)
    end

    def self.build(options={}, &block)
      Magnetic::Path::Builder.build(options, &block)
    end

    def self.draft(options={}, &block)
      Magnetic::Path::Builder.draft(options, &block)
    end
  end
end

require "trailblazer/activity/magnetic/dsl"
require "trailblazer/activity/magnetic/dsl/plus_poles"
require "trailblazer/activity/magnetic/dsl/alterations"

require "trailblazer/activity/magnetic/structures"

require "trailblazer/activity/schema/dependencies"

require "trailblazer/activity/magnetic"
require "trailblazer/activity/magnetic/builder"

require "trailblazer/activity/magnetic/dsl/path"
require "trailblazer/activity/magnetic/dsl/railway"
require "trailblazer/activity/magnetic/dsl/fast_track" # TODO: move to Operation gem.

require "trailblazer/activity/magnetic/generate"
