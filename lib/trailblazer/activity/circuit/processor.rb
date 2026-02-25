 module Trailblazer
  class Activity
    class Circuit
      # Executes a Circuit instance, implementing the code flow logic.
      # A circuit is basically a hash of tasks pointing to their following tasks,
      # keyed by a signal.
      class Processor
        # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
        def self.call(circuit, ctx, lib_ctx, circuit_options, signal) # FIXME: allow {:start_task}.
          # puts "@@@@@??? #{circuit.inspect}"
          # id, task, invoker, circuit_options_to_merge = circuit.to_a_FIXME # we absolutely safely know that we want the start_task here.
          node = circuit.to_a_FIXME # we absolutely safely know that we want the start_task here.

          loop do
          # id = node.first # TODO: it always should be [id, node]
            # puts ">>>Processor #{id.inspect} #{circuit_options_to_merge}"
            ctx, lib_ctx, signal = invoke_task(node, ctx, lib_ctx, circuit_options, signal)

            # puts "   @@@@@ #{id.inspect} ==> #{signal.inspect}"
            node = circuit.resolve(node, signal)

            return ctx, lib_ctx, signal unless node
            # unless ()

              # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
            # end
          end
        end

        # DISCUSS: do we want to merge circuit_options here? Definitely more flexible?
        def self.invoke_task(node, ctx, lib_ctx, circuit_options, signal) # DISCUSS: should we directly decompose node for {invoke_task}?
          id, task, invoker, circuit_options_to_merge = node
          # puts id.inspect

           ctx, lib_ctx, signal = invoker.(
            task,
            ctx,
            lib_ctx,
            circuit_options.merge(circuit_options_to_merge),
            signal,
          )
        end

        # Processor that automatically scopes the lib_ctx for this circuit run.
        # Can return a signal via the {:signal} variable that can be set by
        # any step.
        class Scoped < Processor
          # By using kwargs, we allow to change {:copy_to_outer_ctx} at runtime, for a bit
          # of performance tradeoff.
          def self.call(circuit, ctx, lib_ctx, circuit_options, outer_signal)
            lib_ctx = Trailblazer.Context(lib_ctx) # FIXME: this has to be here so we can use super, fuck it.

            ctx, lib_ctx, signal = super(circuit, ctx, lib_ctx, circuit_options, outer_signal) # DISCUSS: should we use {super} here?

            call_with_unscoping(circuit, ctx, lib_ctx, signal, outer_signal, **circuit_options)
          end

          # Scope the incoming {lib_ctx} and write configured variables back to the original {lib_ctx}.
          def self.call_with_unscoping(circuit, ctx, lib_ctx, signal, outer_signal, copy_to_outer_ctx: [], return_outer_signal: false, **circuit_options)
# puts ">>>"
# ap lib_ctx
          # FIXME: use logic from variable-mapping here.
            outer_ctx, mutable = lib_ctx.decompose

            copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
              # DISCUSS: is merge! and slice faster? no it's not.
              outer_ctx[key] = mutable[key] # if the task didn't write anything, we need to ask to big scoped ctx.
            end

              lib_ctx = outer_ctx
            # puts "@@@@@ ++++ #{id} #{copy_to_outer_ctx.inspect} #{mutable}"

            # public_variables = mutable.slice(*copy_to_outer_ctx) # it only makes sense to publish variables if they're "new".
            # lib_ctx = outer_ctx.merge(public_variables)




            # discard the returned signal from this circuit.
            if return_outer_signal
              signal = outer_signal
            end

            return ctx, lib_ctx, signal
          end
        end
      end
    end # Circuit
  end
end



        # def raise_illegal_signal_error!(task, last_signal, outputs, **circuit_options)
        #   raise IllegalSignalError.new(
        #     task,
        #     **circuit_options,
        #     signal: last_signal,
        #     outputs: @map[task],
        #   )
        # end

        # # Common reasons to raise IllegalSignalError are when returning signals from
        # #   * macros which are not registered
        # #   * subprocesses where parent process have not registered that signal
        # #   * ciruit interface steps, for example: `step task: method(:validate)`
        # class IllegalSignalError < RuntimeError
        #   attr_reader :task, :signal

        #   def initialize(task, signal:, outputs:, exec_context:, **)
        #     @task = task
        #     @signal = signal

        #     message = "#{exec_context.class}:\n" \
        #       "\e[31mUnrecognized signal `#{signal.inspect}` returned from #{task.inspect}. Registered signals are:\e[0m\n" \
        #       "\e[32m#{outputs.keys.map(&:inspect).join("\n")}\e[0m"

        #     super(message)
        #   end
        # end
