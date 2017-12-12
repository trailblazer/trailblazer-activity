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

    # def self.inherited(inheriter)
    #   super
    #   inheriter.initialize_activity_dsl!
    #   inheriter.recompile_process!
    # end

    def self.initialize_activity_dsl!
      builder_class, normalizer = config

      @builder = builder_class.new(normalizer, {})
      @debug   = {}
    end

    def self.recompile_process!
      @process, @outputs = Recompile.( @builder.instance_variable_get(:@adds) )
    end

    def self.call(args, circuit_options={})
      @process.( args, circuit_options )
    end

    #- modelling

    # @private
    # DISCUSS: #each instead?
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

    def self.config # FIXME: the normalizer is the same we have in Builder::plan.
      return Magnetic::Builder::Path, Magnetic::Builder::DefaultNormalizer.new(plus_poles: Magnetic::Builder::Path.default_plus_poles)
    end

    # DSL part
    # delegate as much as possible to Builder
    # let us process options and e.g. do :id
    class << self
      extend Forwardable # TODO: test those helpers
      def_delegators :@builder, :Path#, :task

      def task(*args, &block)
        adds, *options = @builder.task(*args, &block)

        recompile_process!

        add_introspection!(adds, *options)

        return adds, options
      end

      private

      def add_introspection!(adds, task, local_options, *)
        @debug[task] = { id: local_options[:id] }.freeze
      end
    end

    # MOVE ME TO ADDS
    module Recompile
      # Recompile the process and outputs from the {ADDS} instance that collects circuit tasks and connections.
      def self.call(adds)
        process, end_events = Magnetic::Builder.finalize(adds)
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
