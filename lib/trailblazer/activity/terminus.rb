module Trailblazer
  class Activity
    # A terminus is just another task exposing the circuit interface,
    # returning itself as the signal.
    class Terminus# < Circuit::Node
      class Success < Struct.new(:semantic, keyword_init: true)
        # Invoked in Runner.
        # A terminus is a Node that doesn't do anything but return itself as a signal,
        # bypassing all logic such as scoping.
        def call(ctx, lib_ctx, signal, **)
          return ctx, lib_ctx, self
        end
      end

      class Failure < Success
      end
    end
  end
end
