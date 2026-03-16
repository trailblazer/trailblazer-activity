module Trailblazer
  # This is DSL-independent code, focusing only on run-time.
  #
  # Developer's docs: https://trailblazer.to/2.1/docs/internals.html#internals-activity
  class Activity
  end # Activity
end

require "trailblazer/activity/circuit"
require "trailblazer/activity/circuit/context"
require "trailblazer/activity/circuit/node"
require "trailblazer/activity/circuit/node/scoped"
require "trailblazer/activity/circuit/node/runner"
require "trailblazer/activity/circuit/node/introspect"
require "trailblazer/activity/circuit/pipeline"
require "trailblazer/activity/circuit/processor"
require "trailblazer/activity/circuit/task/adapter"
require "trailblazer/activity/circuit/builder"
require "trailblazer/activity/circuit/adds"
require "trailblazer/activity/circuit/wrap_runtime/runner"
require "trailblazer/activity/circuit/wrap_runtime/extension"
require "trailblazer/activity/signal"
require "trailblazer/activity/terminus"
require "trailblazer/activity/step" # ComputeBinarySignal.
