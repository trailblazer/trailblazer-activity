module Trailblazer
  class Activity
    class Circuit
      class Node
        class Processor # DISCUSS: name?
          def self.call(node, ctx, lib_ctx, signal, circuit_options, **)
            id, task, interface_invoker, merge_to_lib_ctx = node

            interface_invoker.(task, ctx, lib_ctx, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
          end

          class Scoped < Processor
            def self.call(node, ctx, outer_lib_ctx, outer_signal, circuit_options, copy_from_outer_ctx: nil, return_outer_signal: false, copy_to_outer_ctx: [], **options)# FIXME: we need to "cleanse" the circuit_options from any configuration, dangerous. waht if a higher node has a config that is not filtered out by the Node runner?
              id, task, _, merge_to_lib_ctx = node
              # puts "@@@@@ ??? #{merge_to_lib_ctx.inspect}"

              new_lib_ctx = outer_lib_ctx
              # FIXME: slice or something
              if copy_from_outer_ctx
                new_lib_ctx = copy_from_outer_ctx.collect { |key| [key, outer_lib_ctx[key]] }.to_h
              end

              lib_ctx = Trailblazer::Context.new(new_lib_ctx, merge_to_lib_ctx.dup) # FIXME: add tests where we make sure we're dupping here, otherwise it starts bleeding!
puts "))) before #{id}: #{lib_ctx}"
              ctx, lib_ctx, signal = super(node, ctx, lib_ctx, signal, circuit_options, **options)

              lib_ctx, signal = unscope(lib_ctx, outer_lib_ctx, signal, outer_signal, return_outer_signal: return_outer_signal, copy_to_outer_ctx: copy_to_outer_ctx)
                puts "@@@@ after #{id}!@ #{lib_ctx.inspect}"

              return ctx, lib_ctx, signal
            end

            # @private
            def self.unscope(lib_ctx, outer_ctx, signal, outer_signal, return_outer_signal:, copy_to_outer_ctx:)
              # outer_ctx, mutable = lib_ctx.decompose
              _FIXME_outer_ctx, mutable = lib_ctx.decompose

                  copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
                    # DISCUSS: is merge! and slice faster? no it's not.
                    # outer_ctx[key] = mutable[key] # if the task didn't write anything, we need to ask to big scoped ctx.
                    outer_ctx[key] = lib_ctx[key] # if the task didn't write anything, we need to ask to big scoped ctx.
                  end

                  # raise "some pipes don't update :stack, that's why it is nil in mutable[:stack]"

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
