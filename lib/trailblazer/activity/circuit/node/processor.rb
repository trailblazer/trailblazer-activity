module Trailblazer
  class Activity
    class Circuit
      class Node
        class Processor # DISCUSS: name?
          def self.call(node, ctx, lib_ctx, signal, **circuit_options)
            id, task, interface_invoker, merge_to_lib_ctx = node
            interface_invoker.(task, ctx, lib_ctx, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
          end

          class Scoped < Processor
            def self.call(node, ctx, outer_lib_ctx, outer_signal, copy_from_outer_ctx: nil, return_outer_signal: false, copy_to_outer_ctx: [], **circuit_options)# FIXME: we need to "cleanse" the circuit_options from any configuration, dangerous. waht if a higher node has a config that is not filtered out by the Node runner?
              id, task, _, merge_to_lib_ctx = node
              # puts "@@@@@ ??? #{merge_to_lib_ctx.inspect}"


              lib_ctx = Trailblazer::Context.scope_FIXME(outer_lib_ctx, copy_from_outer_ctx, merge_to_lib_ctx)

# puts "))) before #{id}: #{lib_ctx}"
# puts "calling #{id} with signal <<<#{signal}"
              ctx, lib_ctx, signal = super(node, ctx, lib_ctx, outer_signal, **circuit_options)

                # puts "@@@@ after #{id}!@ #{signal.inspect}"
              lib_ctx, signal = unscope(lib_ctx, outer_lib_ctx, signal, outer_signal, return_outer_signal: return_outer_signal, copy_to_outer_ctx: copy_to_outer_ctx)

              return ctx, lib_ctx, signal
            end

            # @private
            def self.unscope(lib_ctx, outer_ctx, signal, outer_signal, return_outer_signal:, copy_to_outer_ctx:)
              # Per default, we do NOT copy anything to {outer_ctx}.
              lib_ctx = Trailblazer::Context.unscope_FIXME!(outer_ctx, lib_ctx, copy_to_outer_ctx)
                  # puts "@@@@@ ++++ #{id} #{copy_to_outer_ctx.inspect} #{mutable}"

                  # public_variables = mutable.slice(*copy_to_outer_ctx) # it only makes sense to publish variables if they're "new".
                  # lib_ctx = outer_ctx.merge(public_variables)
                  # puts "finished processing Scoped.call"
                  # puts "   #{lib_ctx.to_h}"



                  # discard the returned signal from this circuit.
                  if return_outer_signal
                    signal = outer_signal
                  end

              return lib_ctx, signal
            end
          end
        end
      end
    end # Circuit
  end
end
