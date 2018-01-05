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

    require "trailblazer/activity/wrap"
    require "trailblazer/wrap/call_task"
    require "trailblazer/wrap/trace"
    require "trailblazer/wrap/runner"
    require "trailblazer/wrap/merge"

    require "trailblazer/activity/trace"
    require "trailblazer/activity/present"


    require "trailblazer/activity/magnetic" # the "magnetic" DSL
    require "trailblazer/activity/schema/sequence"

    require "trailblazer/activity/process"
    require "trailblazer/activity/introspection"

    require "trailblazer/activity/heritage"

    def self.call(args, circuit_options={})
      @process.( args, circuit_options )
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

    def self.inherited(subclass)
      super
      subclass.initialize!(*subclass.config)
      heritage.(subclass)
    end

    def self.initialize!(builder_class, normalizer)
      initialize_activity_dsl!(builder_class, normalizer)
      recompile_process!
    end

    # builder is stateless, it's up to you to save @adds somewhere.
    def self.initialize_activity_dsl!(builder_class, normalizer)
      @builder, @adds = builder_class.for( normalizer ) # e.g. Path.for(...) which creates a Builder::Path instance.
      @debug          = {} # only @adds and @debug are mutable
    end

    def self.recompile_process!
      @process, @outputs = Recompile.( @adds )
    end

    def self.config # FIXME: the normalizer is the same we have in Builder::plan.
      return Magnetic::Builder::Path, Magnetic::Builder::DefaultNormalizer.new(plus_poles: Magnetic::Builder::Path.default_plus_poles)
    end

    # DSL part

    # DISCUSS: make this functions and don't include?
    module DSL

      # Create a new method (e.g. Activity::step) that delegates to its builder, recompiles
      # the process, etc. Method comes in a module so it can be overridden via modules.
      #
      # This approach assumes you maintain a @adds and a @debug instance variable. and #heritage
      def self.def_dsl!(_name)
        Module.new do
          define_method(_name) do |*args, &block|
            _task(_name, *args, &block)  # TODO: similar to Block.
          end
        end
      end

      private

      # @param name (:step|:pass|:fail)
      def _task(name, *args, &block)
        heritage.record(name, *args, &block)

        adds, *returned_options = @builder.send(name, *args, &block)

        @adds += adds
        @adds.freeze

        recompile_process!

        task, local_options, _ = returned_options
        # {Extension API} call all extensions.
        local_options[:extension].collect { |ext| ext.(self, adds, *returned_options) } if local_options[:extension]

        add_introspection!(adds, *returned_options) # DISCUSS: should we use the :extension API here, too?

        return adds, returned_options
      end

      def add_introspection!(adds, task, local_options, *)
        @debug[task] = { id: local_options[:id] }.freeze
      end
    end

    # delegate as much as possible to Builder
    # let us process options and e.g. do :id
    class << self
      extend Forwardable # TODO: test those helpers
      def_delegators :@builder, :Path#, :task
    end

    extend DSL                  # _task, :add_introspection
    extend DSL.def_dsl!(:task)  # define Activity::task.

    extend Heritage::Accessor


    # MOVE ME TO ADDS
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
    end

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
