require "trailblazer/circuit"
require "trailblazer/activity/version"

module Trailblazer
  module Activity
    module Interface
      # @return [Process, Hash, Adds] Adds is private and should not be used in your application as it might get removed.
      def decompose # TODO: test me
        return @process, outputs, @adds, @builder
      end

      def debug # TODO: TEST ME
        @debug
      end

      def outputs
        @outputs
      end
    end

    module DSL
      # Create a new method (e.g. Activity::step) that delegates to its builder, recompiles
      # the process, etc. Method comes in a module so it can be overridden via modules.
      #
      # This approach assumes you maintain a {#add_task!} method.
      def self.def_dsl(_name)
        Module.new do
          define_method(_name) do |task, options={}, &block|
            builder, adds, process, outputs, options = add_task!(_name, task, options, &block)  # TODO: similar to Block.
          end
        end
      end
    end

    module BuildState
      def build_state_for(options)
        BuildState.build_state_for(self.config, options)
      end
      # Compute all objects that need to be passed into the new Activity module.
      # 1. Build the normalizer (unless passed with :normalizer)
      # 2. Build the builder (in State)
      # 3. Let State compute all state variables (that implies recompiling the Process)
      #
      # @api private
      def self.build_state_for(default_options, options)
        options                                  = default_options.merge(options) # TODO: use Variables::Merge() here.
        normalizer, options                      = build_normalizer(options)
        builder, adds, process, outputs, options = build_state(normalizer, options)
      end

      # Builds the normalizer (to process options in DSL calls) unless {:normalizer} is already set.
      #
      # @api private
      def self.build_normalizer(normalizer_class:, normalizer: false, **options)
        normalizer, options = normalizer_class.build( options ) unless normalizer

        return normalizer, options
      end

      def self.build_state(normalizer, builder_class:, builder_options: {}, **options)
        builder, adds, process, outputs = State.build(builder_class, normalizer, options.merge(builder_options))

        return builder, adds, process, outputs, options
      end
    end


    def self.[](implementation=Activity::Path, options={})
      *state = implementation.build_state_for(options)

      # This module would be unnecessary if we had better included/inherited
      # mechanics: https://twitter.com/apotonick/status/953520912682422272
      #   mod = Module.new(state: state) do
      mod = Module.new do
        # we need this method to inject data from here.
        define_singleton_method(:_state){ state } # this sucks so much, but is needed to inject state into the module.
        include implementation # ::task or ::step, etc

        def self.extended(extended)
          super
          extended.initialize!(*_state) # config is from singleton_class.config.
        end
      end
    end


    module Call
      def call(args, argumenter: [], **circuit_options) # DISCUSS: the argumenter logic might be moved out.
        _, args, circuit_options = argumenter.inject( [self, args, circuit_options] ) { |memo, argumenter| argumenter.(*memo) }

        @process.( args, circuit_options.merge(argumenter: argumenter) )
      end
    end

    module Initialize
      # Set all necessary state in the module.
      # @api private
      def initialize!(builder, adds, process, outputs, options)
        @builder, @adds, @process, @outputs, @options = builder, adds, process, outputs, options
        @debug                                        = {} # TODO: hmm.
      end
    end

    module AddTask
      def add_task!(name, task, options, &block)
        # The beautiful thing about State.add is it doesn't mutate anything.
        # We're changing state here, on the outside, by overriding the ivars.
        # That in turn means, the only mutated entity is this module.
        builder, @adds, @process, @outputs, options = State.add(@builder, @adds, name, task, options, &block)
      end
    end



    # TODO: use an Activity here and not super!
    module AddTask
      module ExtensionAPI
        def add_task!(name, task, options, &block)
          builder, adds, process, outputs, options = super
          task, local_options, _ = options

          # {Extension API} call all extensions.
          local_options[:extension].collect { |ext| ext.(self, *options) } if local_options[:extension]
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

    module PublicAPI
      # Include all DSL methods here as instance method, these get imported
      # via extend.
      include Activity::Initialize
      include Activity::Call

      include Activity::AddTask
      include AddTask::ExtensionAPI

      include Activity::Interface # DISCUSS

      include DSLHelper # DISCUSS

      include Activity::Inspect # DISCUSS

    require "trailblazer/activity/magnetic/merge"
      include Magnetic::Merge # Activity#merge!
    end
  end # Activity
end

require "trailblazer/activity/structures"

require "trailblazer/activity/path"
require "trailblazer/activity/railway"
require "trailblazer/activity/fast_track"

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
