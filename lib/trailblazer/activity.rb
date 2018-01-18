require "trailblazer/circuit"

require "trailblazer/activity/version"
require "trailblazer/activity/structures"

# require "trailblazer/activity/subprocess"

require "trailblazer/activity/task_wrap"
require "trailblazer/activity/task_wrap/call_task"
require "trailblazer/activity/task_wrap/trace"
require "trailblazer/activity/task_wrap/runner"
require "trailblazer/activity/task_wrap/merge"

require "trailblazer/activity/trace"
require "trailblazer/activity/present"

require "trailblazer/activity/process"
require "trailblazer/activity/introspect"

require "trailblazer/activity/heritage"

require "trailblazer/activity/state"
require "trailblazer/activity/magnetic" # the "magnetic" DSL
require "trailblazer/activity/schema/sequence"

module Trailblazer
  module Activity
    module Interface
      def decompose # TODO: test me
        return @process, outputs
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

    # Implementation module that can be passed to `Activity[]`.
    module Path
      def self.config
        {
          builder_class:  Magnetic::Builder::Path,
          normalizer:     Magnetic::Builder::DefaultNormalizer.new(
                            plus_poles: Magnetic::Builder::Path.default_plus_poles,
                            extension:  [ Introspect.method(:add_introspection) ],
                          ),
        }
      end

      include DSL.def_dsl(:task)  # define Path::task.
    end

    # Implementation module that can be passed to `Activity[]`.
    module Railway
      def self.config # FIXME: the normalizer is the same we have in Builder::plan.
        {
          builder_class: Magnetic::Builder::Railway,
          normalizer:    Magnetic::Builder::DefaultNormalizer.new(plus_poles: Magnetic::Builder::Railway.default_plus_poles),
        }
      end

      include DSL.def_dsl(:step)
      include DSL.def_dsl(:fail)
      include DSL.def_dsl(:pass)
    end





    # module doesn't allow inheritance ==> Activity.merge instead (composition)
    # module doesn't allow state       ==> write to ctx object
    # module allows to say "when" "inheritance" is done




    def self.[](implementation=Activity::Path, options={})
      # This module would be unnecessary if we had better included/inherited
      # mechanics: https://twitter.com/apotonick/status/953520912682422272
      mod = Module.new do
        # we need this method to inject data from here.
        options = implementation.config.merge(options)
        singleton_class.define_method(:config){ options } # this sucks so much, why does Ruby make it so hard?

        include implementation # ::task or ::step, etc

        def self.extended(extended)
          super
          extended.initialize_activity!(config) # config is from singleton_class.config.
        end

        # Include all DSL methods here as instance method, these get imported
        # via extend.
        include Activity::Initialize
        include Activity::Call
        include Activity::AddTask

        include Activity::Interface # DISCUSS

        include Activity::DSLDelegates # DISCUSS

        include Activity::Inspect # DISCUSS
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
      def initialize_activity!(builder_class:, normalizer:, builder_options: {}, **options)
        @builder, @adds, @process, @outputs = State.build(builder_class, normalizer, builder_options)

        @debug    = {}
        @options  = options
      end
    end

    module AddTask
      def add_task!(name, task, options, &block)
        builder, @adds, @process, @outputs, options = State.add(@builder, @adds, name, task, options, &block)
      end
    end



    # TODO: use an Activity here and not super!
    module AddTask
      module ExtensionAPI
        def add_task!(name, task, options, &block)
          options[:extension] ||= [] # FIXME: mutant!

          builder, adds, process, outputs, options = super
          task, local_options, _ = options

          # {Extension API} call all extensions.
          local_options[:extension].collect { |ext| ext.(self, *options) } if local_options[:extension]
        end
      end
    end

    # extend AddTask::ExtensionAPI



    # delegate as much as possible to Builder
    # let us process options and e.g. do :id
    module DSLDelegates
      extend Forwardable # TODO: test those helpers
      def_delegators :@builder, :Path, :Output#, :task
    end


# require "trailblazer/activity/magnetic/builder/normalizer" # DISCUSS: name and location are odd. This one uses Activity ;)

  module Inspect
    def inspect
      "#<Trailblazer::Activity: {#{name || @options[:name]}}>"
    end
  end
end
end

