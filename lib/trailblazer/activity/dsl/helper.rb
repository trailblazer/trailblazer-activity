module Trailblazer
  module Activity::DSL
    # Create a new method (e.g. Activity::step) that delegates to its builder, recompiles
    # the circuit, etc. Method comes in a module so it can be overridden via modules.
    #
    # This approach assumes you maintain a {#add_task!} method.
    def self.def_dsl(_name, strategy, polarizer)
      Module.new do
        define_method(_name) do |task, options={}, &block|
          builder, adds, circuit, outputs, options = add_task!(strategy, polarizer, _name, task, options, &block)  # TODO: similar to Block.
        end
      end
    end

    # @api private
    OutputSemantic = Struct.new(:value)

    # Shortcut functions for the DSL. These have no state.
    module Helper
      module_function

      #   Output( Left, :failure )
      #   Output( :failure ) #=> Output::Semantic
      def Output(signal, semantic=nil)
        return OutputSemantic.new(signal) if semantic.nil?

        Activity.Output(signal, semantic)
      end

      def End(semantic)
        Activity.End(semantic)
      end

      def Path(normalizer, track_color: "track_#{rand}", end_semantic: track_color, **options)
        options = options.merge(track_color: track_color, end_semantic: end_semantic)

        # Build an anonymous class which will be where the block is evaluated in.
        # We use the same normalizer here, so DSL calls in the inner block have the same behavior.
        path = Module.new do
          extend Activity::Path( options.merge( normalizer: normalizer ) )
        end

        # this block is called in DSL::ProcessTuples. This could be improved somehow.
        ->(block) {
          path.instance_exec(&block)

          [ track_color, path ]
        }
      end

      # Computes the :outputs options for {activity}
      def Subprocess(activity)
        {
          task:    activity,
          outputs: activity.outputs
        }
      end
    end
  end
end
