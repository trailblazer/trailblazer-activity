 module Trailblazer
  class Activity
    class Circuit
      # Executes a Circuit instance, implementing the code flow logic.
      # A circuit is basically a hash of tasks pointing to their following tasks,
      # keyed by a signal.
      class Processor
        # TODO: this can still be optimized for runtime speed.
        def self.call(circuit, ctx, lib_ctx, **circuit_options) # TODO: allow {:start_task}.
          id, task, invoker, circuit_options_to_merge = circuit.to_a_FIXME

          loop do
            # puts ">>>Processor #{id.inspect}"
            ctx, lib_ctx, signal = invoker.(
              task,
              ctx,
              lib_ctx,
              **circuit_options.merge(circuit_options_to_merge),
            )

            # puts "   @@@@@ #{id.inspect} ==> #{signal.inspect}"
            unless (id, task, invoker, circuit_options_to_merge = circuit.resolve(id, signal))
              return ctx, lib_ctx, signal
              # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
            end
          end
        end

        # Processor that automatically scopes the ctx for this circuit run.
        # Can return a signal via the {:signal} variable that can be set by
        # any step.
        class Scoped < Processor
          # By using kwargs, we allow to change {:copy_to_outer_ctx} at runtime, for a bit
          # of performance tradeoff.
          def self.call(circuit, ctx, lib_ctx, copy_to_outer_ctx:, emit_signal: false, **circuit_options)
            lib_ctx = Trailblazer.Context(lib_ctx)

            ctx, lib_ctx, signal = super(circuit, ctx, lib_ctx, **circuit_options)

            outer_ctx, mutable = lib_ctx.decompose

            # puts "@@@@@ ++++ #{id} #{copy_to_outer_ctx.inspect} #{mutable}"
            copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
              # DISCUSS: is merge! and slice faster?
              # outer_ctx[key] = mutable[key]
              outer_ctx[key] = lib_ctx[key] # if the task didn't write anything, we need to ask to big scoped ctx.
            end

            lib_ctx = outer_ctx

            if emit_signal
              signal = mutable[:signal] # FIXME: is it always here in mutable?
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
