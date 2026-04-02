module Trailblazer
  # This is DSL-independent code, focusing only on run-time.
  #
  # Developer's docs: https://trailblazer.to/2.1/docs/internals.html#internals-activity
  class Activity
  end # Activity
end


require "trailblazer/circuit"
require "trailblazer/activity/signal"
require "trailblazer/activity/terminus"
require "trailblazer/activity/step" # ComputeBinarySignal.
