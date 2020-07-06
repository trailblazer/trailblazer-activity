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
        **(circuit_options.merge(activity: self))
      )
    end

    # Reader and writer method for an Activity.
    # The writer {dsl[:key] = "value"} exposes immutable behavior and will replace the old
    # @state with a new, modified copy.
    #
    # Always use the accessors to avoid leaking state to other components
    # due to mutable write operations.
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
require "trailblazer/activity/circuit"
require "trailblazer/activity/config"
require "trailblazer/activity/introspect"
require "trailblazer/activity/task_wrap"
require "trailblazer/activity/task_builder"

require "trailblazer/option"
require "trailblazer/context"


