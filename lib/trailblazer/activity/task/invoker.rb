 module Trailblazer
  class Activity
    class Task
      module Invoker
        class CircuitInterface
          def self.call(task, ctx, **circuit_options)
            task.(ctx, **ctx, **circuit_options)
          end

          class InstanceMethod
            def self.call(task, ctx, exec_context:, **)
              exec_context.send(task, ctx, **ctx.to_h) # TODO: how to add kwargs for Rescue.
              # FIXME: we're NOT passing circuit_options to instance method?
            end
          end
        end
      end
    end # Task
  end
end
