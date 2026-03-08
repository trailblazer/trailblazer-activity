 module Trailblazer
  class Activity
    class Circuit
      # This is the only overridable part of Processor where we know,
      # at runtime, what is the next step.
      class Node
        # A Runner is called in {Circuit::Processor.call} to process and
        # run a task (which is part of a node).
        #
        # Runner currently simply delegates to "scope" (formerly Node::Processor but the name sucks.)
        # It automatically merges "scoping options/configuration" at runtime, so this can be extended, too
        # (e.g. for tracing).
        class Runner
          def self.call(node, ctx, lib_ctx, signal, **circuit_options)
            id, task, invoker, _, scope, local_circuit_options = node

# FIXME: to inject :start_task, we'd have to merge into circuit_options, not local_circuit_options, but also only for one particular "level"/node.

            # DISCUSS: not entirely sure that the Runner will be the abstraction/component where we merge circuit_options etc.
            # DISCUSS: which place is the correct place to embrace Node details?

# raise "we're leaking config into children calls here. because node contains options that are hardcore-mixed with circuit_options"
            scope.(node, ctx, lib_ctx, signal, **circuit_options, **local_circuit_options) # FIXME: we're leaking config into children calls here.
          end

        end
      end
    end # Circuit
  end
end
