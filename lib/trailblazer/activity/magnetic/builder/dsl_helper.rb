module Trailblazer
  # Shortcut functions for the DSL. These have no state.
  module Activity::Magnetic::Builder::DSLHelper
    module_function

    #   Output( Left, :failure )
    #   Output( :failure ) #=> Output::Semantic
    def Output(signal, semantic=nil)
      return Activity::Magnetic::DSL::Output::Semantic.new(signal) if semantic.nil?

      Activity.Output(signal, semantic)
    end

    def End(name, semantic)
      Activity.End(name, semantic)
    end

    def Path(normalizer, track_color: "track_#{rand}", end_semantic: :success, **options)
      options    = options.merge(track_color: track_color, end_semantic: end_semantic)

      # Build an anonymous class which will be where the block is evaluated in.
      # We use the same normalizer here, so DSL calls in the inner block have the same behavior.
      path = Module.new do
        extend Activity[ Activity::Path, options.merge( normalizer: normalizer ) ]
      end

      # this block is called in DSL::ProcessTuples. This could be improved somehow.
      ->(block) {
        path.instance_exec(&block)

        [ track_color, path ]
      }
    end
  end
end
