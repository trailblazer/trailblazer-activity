 module Trailblazer
  class Activity
    class Task
      module Invoker
        class LibInterface
          def self.call(task, ctx, lib_ctx, _, **)
            # puts "@@@@@ #{ctx.inspect}, LIB  #{lib_ctx}"
            task.(ctx, lib_ctx, **lib_ctx) # DISCUSS: do we want circuit_options?
          end

          class InstanceMethod
            # lib_ctx is the first positional and gets kwarged. DISCUSS: ctx is barely used.
            def self.call(task, ctx, lib_ctx, _, **)
              exec_context = lib_ctx[:exec_context] or raise

              # puts "@@@@@ #{ctx.inspect}, LIB  #{lib_ctx}"
              exec_context.send(task, ctx, lib_ctx, **lib_ctx) # DISCUSS: do we want circuit_options?
            end
          end

          class InstanceMethod____withSignal_FIXME
            # lib_ctx is the first positional and gets kwarged. DISCUSS: ctx is barely used.
            def self.call(task, ctx, lib_ctx, signal, **)
              # puts "@@@@@ ?#{task.inspect}"
              exec_context = lib_ctx[:exec_context] or raise # FIXME: kwargs?

              # puts "@@@@@ #{ctx.inspect}, LIB  #{lib_ctx}"
              exec_context.send(task, ctx, lib_ctx, signal, **lib_ctx) # DISCUSS: do we want circuit_options?
            end
          end

          class InstanceMethod____withSignal_FIXME_and_Circuitoptions
            # lib_ctx is the first positional and gets kwarged. DISCUSS: ctx is barely used.
            def self.call(task, ctx, lib_ctx, signal)
              exec_context = lib_ctx[:exec_context] or raise # FIXME: kwargs?

              # puts "@@@@@ #{ctx.inspect}, LIB  #{lib_ctx}"
              exec_context.send(task, ctx, lib_ctx, signal, **lib_ctx) # DISCUSS: do we want circuit_options?
            end
          end


          class A____withSignal_FIXME
            # lib_ctx is the first positional and gets kwarged. DISCUSS: ctx is barely used.
            def self.call(task, ctx, lib_ctx, circuit_options, signal)

              # puts "@@@@@ #{ctx.inspect}, LIB  #{lib_ctx}"
              task.(ctx, lib_ctx, signal, **lib_ctx) # DISCUSS: do we want circuit_options?
            end
          end
        end

        # class CircuitInterface
        #   def self.call(task, ctx, lib_ctx, signal)
        #     task.(ctx, lib_ctx, signal)
        #   end

        #   class InstanceMethod # DISCUSS: should we remove this? users can use a callable if they really need the circuit interface.
        #     def self.call(task, ctx, lib_ctx, circuit_options, _) # DISCUSS: hm, do we need this?
        #       exec_context = circuit_options.fetch(:exec_context)
        #       # raise "remove me"
        #       exec_context.send(task, ctx, lib_ctx, circuit_options, **ctx.to_h) # TODO: how to add kwargs for Rescue.
        #       # FIXME: we're NOT passing circuit_options to instance method?
        #     end
        #   end
        # end

        # The step interface is only used on the application level.
        class StepInterface
          def self.call(task, ctx, lib_ctx, _, **)
            # target_ctx = ctx[:application_ctx]

            result = run_step(task, ctx, lib_ctx)
            # pp application_ctx

            lib_ctx[:value] = result

            return ctx, lib_ctx, nil # DISCUSS: value. FIXME: redundant to INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT
          end

          def self.run_step(task, ctx, _)
            task.(ctx, **ctx.to_h)
          end

          class InstanceMethod < StepInterface
            def self.run_step(task, ctx, lib_ctx)
              exec_context = lib_ctx[:exec_context] or raise # FIXME: use kwargs

              exec_context.send(task, ctx, **ctx.to_h)
            end
          end
        end # StepInterface
      end
    end # Task

  end
end
