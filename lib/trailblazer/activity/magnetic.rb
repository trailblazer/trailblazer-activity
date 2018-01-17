module Trailblazer
  class Activity
    # all code related to the magnetic building of a circuit hash lives in this namespace.
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

    class Process
      def self.plan(options={}, &block)
        Magnetic::Builder::Path.plan(options, &block)
      end

      def self.build(options={}, &block)
        Magnetic::Builder::Path.build(options, &block)
      end

      def self.draft(options={}, &block) # TODO: remove me!
        Magnetic::Builder::Path.draft(options, &block)
      end
    end

  end
end

require "trailblazer/activity/magnetic/dsl"
require "trailblazer/activity/magnetic/dsl/plus_poles"
require "trailblazer/activity/magnetic/dsl/alterations"

require "trailblazer/activity/schema/dependencies"

require "trailblazer/activity/magnetic"
require "trailblazer/activity/magnetic/builder"
require "trailblazer/option"
require "trailblazer/activity/task_builder"
require "trailblazer/activity/magnetic/builder/default_normalizer"
require "trailblazer/activity/magnetic/builder/block"
require "trailblazer/activity/magnetic/builder/path"
require "trailblazer/activity/magnetic/builder/railway"
require "trailblazer/activity/magnetic/builder/fast_track" # TODO: move to Operation gem.

require "trailblazer/activity/magnetic/generate"
