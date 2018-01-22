require "trailblazer/activity/version"
require "hamster"

module Trailblazer
  def self.Activity(implementation=Activity::Path, options={})
    Activity.new(implementation, state)
  end

  class Activity < Module
    attr_reader :initial_state

    def initialize(implementation, options)
      builder, adds, circuit, outputs, options = BuildState.build_state_for( implementation.config, options)

      state = Hamster::Hash.new(
        builder: builder,        # immutable
        options: options.freeze, # immutable
        adds:    adds.freeze,
        circuit: circuit.freeze,
        outputs: outputs.freeze,
        debug:   Hamster::Hash.new,
      )

      @initial_state = state

      include *options[:extend] # include the DSL methods.
      include PublicAPI
    end

    def extended(extended)
      super
      extended.instance_variable_set(:@state, initial_state) # initialize!
    end


    module Inspect
      def inspect
        "#<Trailblazer::Activity: {#{name || self[:options][:name]}}>"
      end
    end


    require "trailblazer/activity/dsl/helper"
    # Helpers such as Path, Output, End to be included into {Activity}.
    module DSLHelper
      extend Forwardable
      def_delegators :@builder, :Path
      def_delegators DSL::Helper, :Output, :End

      def Path(*args, &block)
        self[:builder].Path(*args, &block)
      end
    end

    # By including those modules, we create instance methods.
    # Later, this module is `extended` in Path, Railway and FastTrack, and
    # imports the DSL methods as class methods.
    module PublicAPI
      def []=(*args)
        return @state = @state.put(:adds, args[1]) if args.size == 2

        @state = @state.update_in(args[0..-2]) { args[-1].freeze }
      end

      def [](directive)
        @state[directive]
      end




      # include Accessor
    require "trailblazer/activity/dsl/add_task"
      include DSL::AddTask

    require "trailblazer/activity/implementation/interface"
      include Activity::Interface # DISCUSS

      include DSLHelper # DISCUSS

      include Activity::Inspect # DISCUSS

    require "trailblazer/activity/magnetic/merge"
      include Magnetic::Merge # Activity#merge!

      def call(args, argumenter: [], **circuit_options) # DISCUSS: the argumenter logic might be moved out.
        _, args, circuit_options = argumenter.inject( [self, args, circuit_options] ) { |memo, argumenter| argumenter.(*memo) }

        self[:circuit].( args, circuit_options.merge(argumenter: argumenter) )
      end
    end
  end # Activity
end

require "trailblazer/circuit"
require "trailblazer/activity/structures"

require "trailblazer/activity/implementation/build_state"
require "trailblazer/activity/implementation/interface"
require "trailblazer/activity/implementation/path"
require "trailblazer/activity/implementation/railway"
require "trailblazer/activity/implementation/fast_track"

require "trailblazer/activity/task_wrap"
require "trailblazer/activity/task_wrap/call_task"
require "trailblazer/activity/task_wrap/trace"
require "trailblazer/activity/task_wrap/runner"
require "trailblazer/activity/task_wrap/merge"

require "trailblazer/activity/trace"
require "trailblazer/activity/present"

require "trailblazer/activity/introspect"

# require "trailblazer/activity/heritage"
require "trailblazer/activity/subprocess"

require "trailblazer/activity/state"
require "trailblazer/activity/magnetic" # the "magnetic" DSL
require "trailblazer/activity/schema/sequence"

require "trailblazer/activity/magnetic/builder/normalizer" # DISCUSS: name and location are odd. This one uses Activity ;)
