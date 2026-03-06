 module Trailblazer
  class Activity
    class Circuit
      # This is the only overridable part of Processor where we know,
      # at runtime, what is the next step.
      class Node
        # A Runner is called in {Circuit::Processor.call} to process and
        # run a task (which is part of a node).
        class Runner
          def self.call(node, ctx, lib_ctx, signal, **circuit_options)
            id, task, invoker, _, scope, node_process_options = node

# raise "we're leaking config into children calls here. because node contains options that are hardcore-mixed with circuit_options"
            scope.(node, ctx, lib_ctx, signal, circuit_options, **node_process_options) # FIXME: we're leaking config into children calls here.
          end

        end
      end
    end # Circuit
  end
end
