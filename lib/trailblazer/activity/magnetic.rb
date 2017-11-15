module Trailblazer
  class Activity
    module Magnetic
    end

    def self.plan(options={}, &block)
      builder = Magnetic::Path::Builder.new(
        {
          plus_poles: Magnetic::DSL::PlusPoles.new.merge(
            # Activity::Magnetic.Output(Circuit::Right, :success) => :success
            Magnetic.Output(Circuit::Right, :success) => nil
          ).freeze,


        }.merge(options)
      )

      # TODO: pass new edge color in block?
      builder.instance_exec( &block)

      tripletts = builder.draft
      # pp tripletts

      # circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )
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
