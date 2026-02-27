module Trailblazer
  class Activity
    class Circuit
      class Node
        class Processor # DISCUSS: name?
          def self.call(node, ctx, lib_ctx, signal, **)
            id, task, interface_invoker, merge_to_lib_ctx = node

            interface_invoker.(task, ctx, lib_ctx, signal) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
          end

          class Scoped < Processor
            def self.call(node, ctx, outer_lib_ctx, outer_signal, **node_processor_options)
              id, task, _, merge_to_lib_ctx = node
              # puts "@@@@@ ??? #{merge_to_lib_ctx.inspect}"

              lib_ctx = Trailblazer::Context.new(outer_lib_ctx, merge_to_lib_ctx.dup) # FIXME: add tests where we make sure we're dupping here, otherwise it starts bleeding!

              ctx, lib_ctx, signal = super(node, ctx, lib_ctx, signal, **node_processor_options)

              lib_ctx, signal = unscope(lib_ctx, outer_lib_ctx, signal, outer_signal, **node_processor_options)

              return ctx, lib_ctx, signal
            end

            # @private
            def self.unscope(lib_ctx, outer_ctx, signal, outer_signal, return_outer_signal: false, copy_to_outer_ctx: [])
              # outer_ctx, mutable = lib_ctx.decompose
              _FIXME_outer_ctx, mutable = lib_ctx.decompose

                  copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
                    # DISCUSS: is merge! and slice faster? no it's not.
                    outer_ctx[key] = mutable[key] # if the task didn't write anything, we need to ask to big scoped ctx.
                  end

                    lib_ctx = outer_ctx
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
