class Trailblazer::Activity
  module TaskWrap
    # Creates taskWrap steps to map variables before and after the actual step.
    # We hook into the Normalizer, process `:input` and `:output` directives and
    # translate them into a {DSL::Extension}.
    #
    # Note that the two options are not the only way to create filters, you can use the
    # more low-level {Scoped()} etc., too, and write your own filter logic.
    module VariableMapping
      # The taskWrap extension that's included into the static taskWrap for a task.
      def self.Extension(input, output, id: input.object_id)
        Trailblazer::Activity::TaskWrap::Extension(
          merge: merge_for(input, output, id: id),
        )
      end

      # DISCUSS: do we want the automatic wrapping of {input} and {output}?
      def self.merge_for(input, output, id:) # TODO: rename
        [
          [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["task_wrap.input", TaskWrap::Input.new(input, id: id)]],
          [TaskWrap::Pipeline.method(:insert_after),  "task_wrap.call_task", ["task_wrap.output", TaskWrap::Output.new(output, id: id)]],
        ]
      end
    end

    # TaskWrap step to compute the incoming {Context} for the wrapped task.
    # This allows renaming, filtering, hiding, of the options passed into the wrapped task.
    #
    # Both Input and Output are typically to be added before and after task_wrap.call_task.
    #
    # @note Assumption: we always have :input _and_ :output, where :input produces a Context and :output decomposes it.

    # Calls your {@filter} and replaces the original ctx with your returned one.
    class Input
      def initialize(filter, id:)
        @filter = filter
        @id     = id
      end

      # {input.call()} is invoked in the circuit.
      # `original_args` are the actual args passed to the wrapped task: [ [ctx, ..], circuit_options ]
      #
      def call(wrap_ctx, original_args)
        # let user compute new ctx for the wrapped task.
        input_ctx = apply_filter(*original_args)

        # decompose the original_args since we want to modify them.
        (original_ctx, original_flow_options), original_circuit_options = original_args

        wrap_ctx = wrap_ctx.merge(@id => original_ctx) # remember the original ctx by the key {@id}.

        # instead of the original Context, pass on the filtered `input_ctx` in the wrap.
        return wrap_ctx, [[input_ctx, original_flow_options], original_circuit_options]
      end

      private

      # Invoke the @filter callable with the original circuit interface.
      def apply_filter((ctx, original_flow_options), original_circuit_options)
        @filter.([ctx, original_flow_options], **original_circuit_options) # returns {new_ctx}.
      end
    end

    # TaskWrap step to compute the outgoing {Context} from the wrapped task.
    # This allows renaming, filtering, hiding, of the options returned from the wrapped task.
    class Output
      def initialize(filter, id:)
        @filter = filter
        @id     = id
      end

      # Runs your filter and replaces the ctx in `wrap_ctx[:return_args]` with the filtered one.
      def call(wrap_ctx, original_args)
        (original_ctx, original_flow_options), original_circuit_options = original_args

        return_args = wrap_ctx[:return_args]

        returned_ctx, returned_flow_options = wrap_ctx[:return_args]  # this is the Context returned from {call}ing the wrapped user task.
        original_ctx                        = wrap_ctx[@id]           # grab the original ctx from before which was set in the {:input} filter.
        # let user compute the output.
        output_ctx = @filter.(returned_ctx, [original_ctx, returned_flow_options], **original_circuit_options)

        wrap_ctx = wrap_ctx.merge( return_args: [output_ctx, returned_flow_options] )

        # and then pass on the "new" context.
        return wrap_ctx, original_args
      end
    end
  end # Wrap
end
