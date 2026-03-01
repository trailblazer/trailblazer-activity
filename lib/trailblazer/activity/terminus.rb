module Trailblazer
  class Activity
    # A terminus is just another task exposing the circuit interface,
    # returning itself as the signal.
    module Terminus
      # Called from process_node, this is a Runner.
      def self.call(node, ctx, lib_ctx, _)
        return ctx, lib_ctx, node[1]
      end

      # Circuit interface.
      class Success < Struct.new(:semantic, keyword_init: true)
      end

      class Failure < Success
      end
    end
  end
end
