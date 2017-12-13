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

    require "trailblazer/activity/trace"
    require "trailblazer/activity/present"


    require "trailblazer/activity/magnetic" # the "magnetic" DSL
    require "trailblazer/activity/schema/sequence"

    require "trailblazer/activity/process"
    require "trailblazer/activity/introspection"

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

    def self.inherited(inheriter)
      super
      inheriter.initialize!(*inheriter.config)
    end

    def self.initialize!(*args)
      initialize_activity_dsl!(*args)
      recompile_process!
    end

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
      def self.def_dsl!(_name)
        mod = Module.new

        mod.send( :define_method, _name) do |*args, &block|
          _task(_name, *args, &block)  # TODO: similar to Block.
        end

        mod
      end

      private

      def _task(name, *args, &block)
        adds, *returned_options = @builder.send(name, *args, &block)

        @adds += adds

        recompile_process!
        add_introspection!(adds, *returned_options)

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

    extend DSL # _task, :add_introspection
    extend DSL.def_dsl!(:task)


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

      def self.step(*args, &block)
        adds, *options = @builder.step(*args, &block)

        recompile_process!

        add_introspection!(adds, *options)

        return adds, options
      end
    end
  end
end
