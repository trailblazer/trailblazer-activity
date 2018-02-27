module Trailblazer
  class Activity < Module   # all code related to the magnetic building of a circuit hash lives in this namespace.
    module Magnetic
      # PlusPole "radiates" a color that MinusPoles are attracted to.
      #
      # This datastructure is produced by the DSL and sits in an ADDS.
      PlusPole = Struct.new(:output, :color) do
        private :output

        def signal
          output.signal
        end
      end # PlusPole
    end
  end
end

require "trailblazer/activity/dsl/magnetic/process_options"
require "trailblazer/activity/dsl/magnetic/structure/plus_poles"
require "trailblazer/activity/dsl/magnetic/structure/polarization"
require "trailblazer/activity/dsl/magnetic/structure/alterations"

require "trailblazer/activity/dsl/magnetic"
require "trailblazer/activity/dsl/magnetic/builder"
# require "trailblazer/activity/dsl/magnetic/builder/dsl_helper"
# require "trailblazer/activity/dsl/magnetic/dsl_helper"

require "trailblazer/option"
require "trailblazer/activity/task_builder"
require "trailblazer/activity/dsl/magnetic/builder/default_normalizer"
require "trailblazer/activity/dsl/magnetic/builder/path"
require "trailblazer/activity/dsl/magnetic/builder/railway"
require "trailblazer/activity/dsl/magnetic/builder/fast_track" # TODO: move to Operation gem.

require "trailblazer/activity/dsl/magnetic/generate"
require "trailblazer/activity/dsl/magnetic/finalizer"
