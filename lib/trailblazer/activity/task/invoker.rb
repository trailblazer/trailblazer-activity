 module Trailblazer
  class Activity
    class Task
      module Invoker
        class CircuitInterface
          def self.call(task, ctx, **circuit_options)
            task.(ctx, **ctx.to_h, **circuit_options) # DISCUSS: technically, this is repeating code here, see InstanceMethod!
          end

          class InstanceMethod
            def self.call(task, ctx, exec_context:, **)
              exec_context.send(task, ctx, **ctx.to_h) # TODO: how to add kwargs for Rescue.
              # FIXME: we're NOT passing circuit_options to instance method?
            end
          end
        end

        # The step interface is only used on the application level.
        class StepInterface
          def self.call(task, ctx, **circuit_options)
            target_ctx = ctx[:application_ctx]

            result = run_step(task, target_ctx, **circuit_options)
            # pp application_ctx

            ctx[:value] = result

            return ctx, nil # DISCUSS: value. FIXME: redundant to INVOKER___STEP_INTERFACE_ON_EXEC_CONTEXT
          end

          def self.run_step(task, ctx, **)
            task.(ctx, **ctx.to_h)
          end

          class InstanceMethod < StepInterface
            def self.run_step(task, ctx, exec_context:, **)
              exec_context.send(task, ctx, **ctx.to_h)
            end
          end
        end # StepInterface
      end
    end # Task

  end
end
