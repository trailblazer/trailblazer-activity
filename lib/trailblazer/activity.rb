require "trailblazer/circuit"

module Trailblazer
  class Activity
    module Interface
      def decompose # TODO: test me
        return @process, @outputs
      end

      def debug # TODO: TEST ME
        @debug
      end

      def outputs
        @outputs
      end
    end

    extend Interface

    require "trailblazer/activity/version"
    require "trailblazer/activity/structures"

    require "trailblazer/activity/subprocess"

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

    def self.call(args, argumenter: [], **circuit_options) # DISCUSS: the argumenter logic might be moved out.
      _, args, circuit_options = argumenter.inject( [self, args, circuit_options] ) { |memo, argumenter| argumenter.(*memo) }

      @process.( args, circuit_options.merge(argumenter: argumenter) )
    end

    #- modelling

    #- DSL part

    def self.build(&block)
      Class.new(self, &block)
    end

    private

    # inheriting a class means instantiate an object
    # Object.new( .. ) allows variables
    # Class.new doesn't, why is this? sucks
    def self.config
      return Magnetic::Builder::Path, Magnetic::Builder::DefaultNormalizer.new(
        plus_poles: Magnetic::Builder::Path.default_plus_poles,
        extension:  [ Introspect.method(:add_introspection) ],
      )
    end

    module ClassMethods
      def inherited(subclass)
        super
        subclass.initialize!(*subclass.config)
        heritage.(subclass)
      end

      # def initialize!(builder_class, normalizer, builder_options={}, name=nil)
      def initialize!(builder_class, normalizer, builder_options={})
        @builder, @adds, @process, @outputs = State.build(builder_class, normalizer, builder_options)

        @debug = {}
      end

      def add_task!(name, task, options, &block)
        @builder, @adds, @process, @outputs, options = State.add(@builder, @adds, name, task, options, &block)
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

      module Heritage
        def add_task!(name, task, options, &block)
          heritage.record(name, task, options, &block)
          super
        end
      end
    end

    extend ClassMethods
    extend AddTask::ExtensionAPI
    extend AddTask::Heritage

    # DSL part

    # DISCUSS: make this functions and don't include?
    module DSL
      # Create a new method (e.g. Activity::step) that delegates to its builder, recompiles
      # the process, etc. Method comes in a module so it can be overridden via modules.
      #
      # This approach assumes you maintain a @adds and a @debug instance variable. and #heritage
      def self.def_dsl!(_name)
        Module.new do
          define_method(_name) do |task, options={}, &block|
            builder, adds, process, outputs, options = add_task!(_name, task, options, &block)  # TODO: similar to Block.
          end
        end
      end
    end

    # delegate as much as possible to Builder
    # let us process options and e.g. do :id
    class << self
      extend Forwardable # TODO: test those helpers
      def_delegators :@builder, :Path#, :task
    end

    extend DSL.def_dsl!(:task)  # define Activity::task.

    extend Heritage::Accessor


require "trailblazer/activity/magnetic/builder/normalizer" # DISCUSS: name and location are odd. This one uses Activity ;)

    # TODO: hm
  #   class Railway < Activity
  #     def self.config # FIXME: the normalizer is the same we have in Builder::plan.
  #       return Magnetic::Builder::Railway, Magnetic::Builder::DefaultNormalizer.new(plus_poles: Magnetic::Builder::Railway.default_plus_poles)
  #     end

  #     extend DSL.def_dsl!(:step)
  #     extend DSL.def_dsl!(:fail)
  #     extend DSL.def_dsl!(:pass)
  #   end

    def self.to_s
      "#<Trailblazer::Activity #{@name} #{object_id}>"
    end
  end
end

