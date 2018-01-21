require "trailblazer/activity/version"

module Trailblazer
  module Activity
    def self.[](implementation=Activity::Path, options={})
      *state = implementation.build_state_for(options)

      # This module would be unnecessary if we had better included/inherited
      # mechanics: https://twitter.com/apotonick/status/953520912682422272
      #   mod = Module.new(state: state) do
      mod = Module.new do
        # we need this method to inject data from here.
        define_singleton_method(:_state){ state } # this sucks so much, but is needed to inject state into the module.

        # @import =>anonModule#task, anonModule#build_state_for, ...
        include implementation

        def self.extended(extended)
          super
          extended.initialize!(*_state) # config is from singleton_class.config.
        end
      end
    end

    # functional API should be like
    # Activity( builder.task ... ,builder.step, .. )

    module Inspect
      def inspect
        "#<Trailblazer::Activity: {#{name || @options[:name]}}>"
      end
    end

      # Helpers such as Path, Output, End to be included into {Activity}.

    require "trailblazer/activity/dsl/helper"
    module DSLHelper
      extend Forwardable
      def_delegators :@builder, :Path
      def_delegators DSL::Helper, :Output, :End
    end

    # By including those modules, we create instance methods.
    # Later, this module is `extended` in Path, Railway and FastTrack, and
    # imports the DSL methods as class methods.
    module PublicAPI
    require "trailblazer/activity/dsl/add_task"
      include DSL::AddTask

    require "trailblazer/activity/implementation/interface"
      include Activity::Interface # DISCUSS

      include DSLHelper # DISCUSS

      include Activity::Inspect # DISCUSS

    require "trailblazer/activity/magnetic/merge"
      include Magnetic::Merge # Activity#merge!

      # Set all necessary state in the module.
      # @api private
      def initialize!(builder, adds, process, outputs, options)
        @builder, @adds, @process, @outputs, @options = builder, adds, process, outputs, options
        @debug                                        = {} # TODO: hmm.
      end

      def call(args, argumenter: [], **circuit_options) # DISCUSS: the argumenter logic might be moved out.
        _, args, circuit_options = argumenter.inject( [self, args, circuit_options] ) { |memo, argumenter| argumenter.(*memo) }

        @process.( args, circuit_options.merge(argumenter: argumenter) )
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

require "trailblazer/activity/process"
require "trailblazer/activity/introspect"

# require "trailblazer/activity/heritage"
require "trailblazer/activity/subprocess"

require "trailblazer/activity/state"
require "trailblazer/activity/magnetic" # the "magnetic" DSL
require "trailblazer/activity/schema/sequence"

require "trailblazer/activity/magnetic/builder/normalizer" # DISCUSS: name and location are odd. This one uses Activity ;)
