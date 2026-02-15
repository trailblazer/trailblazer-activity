 module Trailblazer
  class Activity
    class Circuit
      # Executes a Circuit instance, implementing the code flow logic.
      # A circuit is basically a hash of tasks pointing to their following tasks,
      # keyed by a signal.
      class Processor
        # TODO: this can still be optimized for runtime speed.
        def self.call(circuit, ctx, **tmp_ctx) # DISCUSS: should we extract or pass-on {:use_outer_tmp}?
          map, start_task_id, termini, config = circuit.to_a # TODO: do that on the outside?


            task_cfg = config[start_task_id]
          loop do
            id, task, invoker, circuit_options_to_merge = task_cfg

            #
            #
            #
            # puts "@@@@@ circuit [invoke] #{id.inspect} #{circuit_options_to_merge}"
            # ctx = ctx.merge(circuit_options_to_merge)

            ctx, signal, tmp = invoker.(
              task,
              ctx,


              **tmp_ctx, # FIXME: prototyping here.
              **circuit_options_to_merge,
            )

            # Stop execution of the circuit when we hit a terminus.
            # puts "@@@@@ #{termini.collect { |o| o} } ??? #{id.inspect}"
            if termini.include?(id)
              # puts "done with circuit #{task}"
              return ctx, signal # FIXME: IS THAT WHAT WE WANT? what if we want to pass in a tmp context into a nested circuit, but don't want it back?
            end

            if next_task_id = next_for(map, id, signal)
              task_cfg = config[next_task_id]
              # puts "@@@@@ =========> #{next_task_id.inspect}"
            else
              raise signal.inspect
              # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
            end
          end
        end

        def self.next_for(map, last_task_id, signal)
          outputs = map[last_task_id]
          outputs[signal]
        end

        class Scoped < Processor
          # By using kwargs, we allow to change {:copy_to_outer_ctx} at runtime, for a bit
          # of performance tradeoff.
          def self.call(circuit, ctx, copy_to_outer_ctx:, emit_signal: false, **circuit_options)
            ctx = Trailblazer.Context(ctx)

            ctx, signal = super(circuit, ctx, **circuit_options)

            outer_ctx, mutable = ctx.decompose

            # puts "@@@@@ ++++ #{id} #{copy_to_outer_ctx.inspect} #{mutable}"
            copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
              # DISCUSS: is merge! and slice faster?
              # outer_ctx[key] = mutable[key]
              outer_ctx[key] = ctx[key] # if the task didn't write anything, we need to ask to big scoped ctx.
            end

            ctx = outer_ctx

            if emit_signal
              signal = mutable[:signal] # FIXME: is it always here in mutable?
            end

            return ctx, signal
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
