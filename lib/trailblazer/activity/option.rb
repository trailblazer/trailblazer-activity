module Trailblazer
  class Activity
    # Since we're always assuming filters exposing a circuit interface, this has been moved
    # into the Activity namespace, yo.
    #
    # TODO: make Option a private concept, make devs use {Circuit.Step} instead.
    class Option # FIXME: remove trailblazer-option.
      def initialize(filter)
        @filter = filter
      end

      # To invoke an instance_method, additional logic is needed, e.g. figuring out the {exec_context}.
      #
      # PROBLEM: we don't know the signature of the instance_method, is it a step, is it circuit interface?
      class InstanceMethod < Option
        def call(*args, keyword_arguments: {}, exec_context: raise("No :exec_context given."), **)
          exec_context.send(@filter, *args, **keyword_arguments)
        end
      end
    end
  end
end
