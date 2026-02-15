 module Trailblazer
  class Activity
    class Task
      module Invoker
        class CircuitInterface
          def self.call(task, ctx, **circuit_options)
            task.(ctx, **ctx, **circuit_options)
          end
        end
      end
    end # Task
  end
end
