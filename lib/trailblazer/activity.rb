require "trailblazer/circuit"

module Trailblazer
  class Activity # DISCUSS: what are we doing with you?
  end # Activity
end

require "trailblazer/activity/signal"
require "trailblazer/activity/terminus"
require "trailblazer/activity/step" # ComputeBinarySignal.
require "trailblazer/activity/invoke"
