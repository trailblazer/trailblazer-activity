module Trailblazer
  module Activity::State
    # Compile-time
    #
    # DISCUSS: we could replace parts with Hamster::Hash.
    module Config
      module_function

      def set(state, *args)
        if args.size == 2
          key, value = *args

          state = state.merge(key => value)
        else
          directive, key, value = *args

          state = state.merge( directive => {}.freeze ) unless state.key?(directive)

          directive_hash = state[directive].merge(key => value)
          state = state.merge( directive => directive_hash.freeze )
        end

        state
      end

      def get(state, *args)
        directive, key = *args

        return state[directive] if args.size == 1
        return state[directive][key] if state.key?(directive)
        nil
      end
    end
  end
end
