module Trailblazer
  class Activity < Module
    attr_reader :initial_state

    def initialize(implementation, options)
      builder, adds, process, outputs_map, options = BuildState.build_state_for( implementation.config, options)

      @initial_state = State::Config.build(
        builder: builder,
        options: options,
        adds:    adds,
        process: process,
        circuit: process.circuit,
        outputs: outputs_map,
      )

      include *options[:extend] # include the DSL methods.
      include PublicAPI
    end

    # Injects the initial configuration into the module defining a new activity.
    def extended(extended)
      super
      extended.instance_variable_set(:@state, initial_state)
    end


    module Inspect
      def inspect
        "#<Trailblazer::Activity: {#{name || self[:options][:name]}}>"
      end

      alias_method :to_s, :inspect
    end


    # Helpers such as Path, Output, End to be included into {Activity}.
    # module DSLHelper
    #   extend Forwardable
    #   def_delegators DSL, :Output, :End, :Subprocess, :Track

    #   def Path(*args, &block)
    #     self[:builder].Path(*args, &block)
    #   end
    # end

    # Reader and writer method for DSL objects.
    # The writer {dsl[:key] = "value"} exposes immutable behavior and will replace the old
    # @state with a new, modified copy.
    #
    # Always use the DSL::Accessor accessors to avoid leaking state to other components
    # due to mutable write operations.
    module Accessor
      def []=(*args)
        @state = State::Config.send(:[]=, @state, *args)
      end

      def [](*args)
        State::Config[@state, *args]
      end
    end

    # FIXME: still to be decided
    # By including those modules, we create instance methods.
    # Later, this module is `extended` in Path, Railway and FastTrack, and
    # imports the DSL methods as class methods.
    module PublicAPI
      include Accessor



      require "trailblazer/activity/interface"
      include Activity::Interface # DISCUSS

      # include DSLHelper # DISCUSS

      include Activity::Inspect # DISCUSS

      # require "trailblazer/activity/dsl/magnetic/merge"
      # include Magnetic::Merge # Activity#merge!

      # @private Note that {Activity.call} is considered private until the public API is stable.
      def call(args, circuit_options={})
        self[:circuit].( args, circuit_options.merge(activity: self) )
      end
    end
  end # Activity
end

require "trailblazer/activity/process"
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


