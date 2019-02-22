module Trailblazer
  class Activity
    def initialize(schema)
      @schema = schema
    end

    def call(args, circuit_options={})
      @schema[:circuit].(
        args,
        circuit_options.merge(activity: self)
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






    module Inspect
      def inspect
        "#<Trailblazer::Activity: {#{name || self[:options][:name]}}>"
      end

      alias_method :to_s, :inspect
    end





    # FIXME: still to be decided
    # By including those modules, we create instance methods.
    # Later, this module is `extended` in Path, Railway and FastTrack, and
    # imports the DSL methods as class methods.
    module PublicAPI
      require "trailblazer/activity/interface"
      include Activity::Interface # DISCUSS

      include Activity::Inspect # DISCUSS

      # require "trailblazer/activity/dsl/magnetic/merge"
      # include Magnetic::Merge # Activity#merge!

      # @private Note that {Activity.call} is considered private until the public API is stable.

    end
  end # Activity
end

require "trailblazer/activity/schema"
require "trailblazer/activity/process/implementation"
require "trailblazer/activity/process/intermediate"
require "trailblazer/activity/circuit"
require "trailblazer/activity/structures"
require "trailblazer/activity/config"

require "trailblazer/activity/task_wrap"
require "trailblazer/activity/task_wrap/pipeline"
require "trailblazer/activity/task_wrap/call_task"
require "trailblazer/activity/task_wrap/runner"
require "trailblazer/activity/task_wrap/variable_mapping"

require "trailblazer/activity/trace"
require "trailblazer/activity/present"

require "trailblazer/activity/introspect"
require "trailblazer/option"
require "trailblazer/activity/task_builder"


