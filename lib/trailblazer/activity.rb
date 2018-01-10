require "trailblazer/circuit"

module Trailblazer
  class Activity
    module Interface
      def decompose # TODO: test me
        @process.instance_variable_get(:@circuit).to_fields
      end

      def debug # TODO: TEST ME
        @debug
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


    require "trailblazer/activity/magnetic" # the "magnetic" DSL
    require "trailblazer/activity/schema/sequence"

    require "trailblazer/activity/process"
    require "trailblazer/activity/introspection"

    require "trailblazer/activity/heritage"

    # @private
    # Goal: abstract away as much as possible for DSL into immutable object.
    module Builder
      Cfg = Struct.new(:builder, :adds, :dsl_methods)

      def self.build(builder_class, normalizer, dsl_methods = [:task])
        cfg = init(builder_class, normalizer, dsl_methods)

        return cfg, *recompile_process(cfg.adds)
      end

      def self.add(cfg, name, *args, &block)
        adds, *returned_options = cfg.builder.send(name, *args, &block)

        adds = cfg.adds + adds

        return Cfg.new(cfg.builder, adds), *recompile_process(adds), returned_options
      end

      private

      def self.init(builder_class, normalizer, dsl_methods = [:task])
        builder, adds = builder_class.for( normalizer ) # e.g. Path.for(...) which creates a Builder::Path instance.

        Cfg.new(builder, adds, dsl_methods).freeze
      end

      def self.recompile_process(adds)
        process, outputs = Recompile.( adds )
      end

      module Recompile
        # Recompile the process and outputs from the {ADDS} instance that collects circuit tasks and connections.
        def self.call(adds)
          process, end_events = Magnetic::Builder::Finalizer.(adds)
          outputs             = recompile_outputs(end_events)

          return process, outputs
        end

        private

        def self.recompile_outputs(end_events)
          ary = end_events.collect do |evt|
            [
              semantic = evt.instance_variable_get(:@options)[:semantic], # DISCUSS: better API here?
              Activity::Output(evt, semantic)
            ]
          end

          ::Hash[ ary ]
        end
      end # Recompile
    end


    def self.call(args, argumenter: [], **circuit_options) # DISCUSS: the argumenter logic might be moved out.
      _, args, circuit_options = argumenter.inject( [self, args, circuit_options] ) { |memo, argumenter| argumenter.(*memo) }

      @process.( args, circuit_options.merge(argumenter: argumenter) )
    end

    #- modelling

    # @private
    # DISCUSS: #each instead?
    # FIXME: move to Introspection
    def self.find(&block)
      @process.instance_variable_get(:@circuit).instance_variable_get(:@map).find(&block)
    end

    def self.outputs
      @outputs
    end

    #- DSL part

    def self.build(&block)
      Class.new(self, &block)
    end

    private

    def self.config
      return Magnetic::Builder::Path, Magnetic::Builder::DefaultNormalizer.new(
        plus_poles: Magnetic::Builder::Path.default_plus_poles,
        extension:  [method(:add_introspection)],
      )
    end

    # {Extension} API
    def self.add_introspection(activity, adds, task, local_options, *returned_options)
      activity.debug[task] = { id: local_options[:id] }.freeze
    end

    module ClassMethods
      def inherited(subclass)
        super
        subclass.initialize!(*subclass.config)
        heritage.(subclass)
      end

      def initialize!(builder_class, normalizer)
        @state, @process, @outputs = Builder.build(builder_class, normalizer)
        @builder = @state.builder # won't change.

        @debug = {}
      end
    end

    extend ClassMethods

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
            options[:extension] ||= []

            @state, @process, @outputs, options = Builder.add(@state, _name, task, options, &block)  # TODO: similar to Block.

            task, local_options, _ = options
            # {Extension API} call all extensions.
            local_options[:extension].collect { |ext| ext.(self, @state, *options) } if local_options[:extension]
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


    # TODO: hm
    class Railway < Activity
      def self.config # FIXME: the normalizer is the same we have in Builder::plan.
        return Magnetic::Builder::Railway, Magnetic::Builder::DefaultNormalizer.new(plus_poles: Magnetic::Builder::Railway.default_plus_poles)
      end

      extend DSL
      extend DSL.def_dsl!(:step)
      extend DSL.def_dsl!(:fail)
      extend DSL.def_dsl!(:pass)
    end
  end
end
