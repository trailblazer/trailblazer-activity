module Trailblazer
  # This is DSL-independent code, focusing only on run-time.
  #
  # Developer's docs: https://trailblazer.to/2.1/docs/internals.html#internals-activity
  class Activity
    def initialize(schema)
      @schema = schema
    end

    def call(ctx, flow_options, circuit_options = {})
      @schema[:circuit].(
        ctx,
        flow_options,
        circuit_options.merge(
          activity: self, # TODO: should this be set on the outside?
        )
      )
    end

    def to_h
      @schema.to_h
    end

    def inspect
      %(#<Trailblazer::Activity:0x#{object_id}>)
    end
  end # Activity
end

require "trailblazer/activity/circuit"
require "trailblazer/activity/circuit/processor"
require "trailblazer/activity/terminus"
require "trailblazer/activity/task/invoker"
require "trailblazer/activity/circuit/builder"

# require "trailblazer/activity/deprecate"
require "trailblazer/activity/structures"
# require "trailblazer/activity/schema"
# require "trailblazer/activity/introspect"
# require "trailblazer/activity/pipeline"
# require "trailblazer/activity/task_wrap/call_task"
# require "trailblazer/activity/task_wrap"
# require "trailblazer/activity/task_wrap/runner"
# require "trailblazer/activity/task_wrap/extension"
# require "trailblazer/activity/adds"
# require "trailblazer/activity/introspect/render"
# require "trailblazer/activity/option"
# require "trailblazer/activity/circuit/step"
# require "trailblazer/context"
