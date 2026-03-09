module Trailblazer
  class Activity
    class Circuit
      class Node < Struct.new(:id, :task, :interface, :merge_to_lib_ctx, :local_circuit_options)
        def call(ctx, lib_ctx, signal, **circuit_options)
          interface.(task, ctx, lib_ctx, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
        end

        class Scoped < Node
          def initialize(*)
            super
            # FIXME: of course, this is only prototyping
            @copy_from_outer_ctx = local_circuit_options[:copy_from_outer_ctx]
            @copy_to_outer_ctx = local_circuit_options[:copy_to_outer_ctx] || []
            @return_outer_signal = local_circuit_options[:return_outer_signal] || false
          end
# FIXME: TRACING needs to extend these parameters at runtime, override them using kwargs or make a new Node instance?
          def call(ctx, outer_lib_ctx, outer_signal, copy_from_outer_ctx: @copy_from_outer_ctx, return_outer_signal: @return_outer_signal, copy_to_outer_ctx: @copy_to_outer_ctx, context_implementation:, **circuit_options)# FIXME: we need to "cleanse" the circuit_options from any configuration, dangerous. waht if a higher node has a config that is not filtered out by the Node runner?
            lib_ctx = context_implementation.scope_FIXME(outer_lib_ctx, copy_from_outer_ctx, merge_to_lib_ctx)

            ctx, lib_ctx, signal = super(ctx, lib_ctx, outer_signal, **circuit_options, context_implementation: context_implementation)

              # puts "@@@@ after #{id}!@ #{signal.inspect}"
            lib_ctx, signal = unscope(lib_ctx, outer_lib_ctx, signal, outer_signal, return_outer_signal, copy_to_outer_ctx, context_implementation)
puts "@@@@@ #{ctx.inspect}"
            return ctx, lib_ctx, signal
          end

          # @private
          def unscope(lib_ctx, outer_ctx, signal, outer_signal, return_outer_signal, copy_to_outer_ctx, context_implementation)
            # Per default, we do NOT copy anything to {outer_ctx}.
            # puts "@@#{local_circuit_options}@@@ #{copy_to_outer_ctx.inspect}"
            lib_ctx = context_implementation.unscope_FIXME!(outer_ctx, lib_ctx, copy_to_outer_ctx)

                # discard the returned signal from this circuit.
                if return_outer_signal
                  signal = outer_signal
                end

            return lib_ctx, signal
          end
        end
      end
    end # Circuit
  end
end
