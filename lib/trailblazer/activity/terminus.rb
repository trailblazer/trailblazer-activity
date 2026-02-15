module Trailblazer
  class Activity
    # A terminus is just another task exposing the circuit interface,
    # returning itself as the signal.
    module Terminus
      class Success < Struct.new(:semantic, keyword_init: true)
        def call(ctx, **)
          return ctx, self
        end
      end

      class Failure < Success
      end
    end
  end
end
