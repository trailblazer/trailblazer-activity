module Trailblazer
  # This is DSL-independent code, focusing only on run-time.
  class Activity
    # include Activity::Interface # TODO

    def initialize(schema)
      @schema = schema
    end

    def call(args, **circuit_options)
      @schema[:circuit].(
        args,
        **circuit_options.merge(activity: self)
      )
    end

    # DISCUSS: we could remove this reader in the future
    # and use {Activity.to_h[:config]}.
    def [](*key)
      @schema[:config][*key]
    end

    def to_h
      @schema
    end

    def inspect
      %{#<Trailblazer::Activity:0x#{object_id}>}
    end
  end # Activity
end

require "trailblazer/activity/structures"
require "trailblazer/activity/schema"
require "trailblazer/activity/schema/implementation"
require "trailblazer/activity/schema/intermediate"
require "trailblazer/activity/circuit"
require "trailblazer/activity/circuit/task_adapter"
require "trailblazer/activity/config"
require "trailblazer/activity/introspect"
require "trailblazer/activity/task_wrap/pipeline"
require "trailblazer/activity/task_wrap/call_task"
require "trailblazer/activity/task_wrap"
require "trailblazer/activity/task_wrap/runner"
require "trailblazer/activity/task_wrap/extension"
require "trailblazer/activity/adds"
require "trailblazer/option"
require "trailblazer/context"


