require "trailblazer/circuit"

# TODO: move to separate gem.
require "trailblazer/option"
require "trailblazer/context"
require "trailblazer/container_chain"

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
    require "trailblazer/wrap/variable_mapping"
    require "trailblazer/wrap/call_task"
    require "trailblazer/wrap/trace"
    require "trailblazer/wrap/runner"

    require "trailblazer/activity/trace"
    require "trailblazer/activity/present"


    require "trailblazer/activity/magnetic" # the "magnetic" DSL
    require "trailblazer/activity/schema/sequence"

    require "trailblazer/activity/process"
    require "trailblazer/activity/magnetic/builder/introspection"

    def self.inherited(inheriter)
      inheriter.initialize_activity_dsl!
      inheriter.recompile_process!
    end

    def self.initialize_activity_dsl!
      @builder = builder_class.new(Normalizer, {})
      @debug   = {}
    end

    def self.recompile_process!
      @process, end_events = Magnetic::Builder.finalize( @builder.instance_variable_get(:@adds) )
      @outputs = recompile_outputs!(end_events)
    end

    def self.recompile_outputs!(end_events)
      ary = end_events.collect do |evt|
        [
          semantic = evt.instance_variable_get(:@options)[:semantic], # DISCUSS: better API here?
          Output(evt, semantic)
        ]
      end

      ::Hash[ ary ]
    end

    def self.call(args, circuit_options={})
      @process.( args, circuit_options.merge( exec_context:  new ) ) # DISCUSS: do we even need that?
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
      Class.new(Activity, &block)
    end

    private

    def self.builder_class
      Magnetic::Builder::Path
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

    class Normalizer # FIXME: copied from Builder::Path.
      def self.call(task, options, sequence_options)
        options =
          {
            plus_poles: initial_plus_poles,
            id:         task.inspect, # TODO.
          }.merge(options)

        return task, options, sequence_options
      end

      def self.initial_plus_poles
        Magnetic::DSL::PlusPoles.new.merge(
          Activity.Output(Circuit::Right, :success) => nil
        ).freeze
      end
    end

  end
end
