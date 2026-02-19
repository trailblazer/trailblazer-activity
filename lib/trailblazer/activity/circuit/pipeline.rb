module Trailblazer
  class Activity
    class Circuit
      class Pipeline < Circuit
        # Pipeline#resolve simply ignores the signal.
        def resolve(last_task_id, signal)
          next_task_id = map[last_task_id][nil]

          config[next_task_id]
        end
      end
    end # Circuit
  end
end
