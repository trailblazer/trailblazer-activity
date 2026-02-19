module Trailblazer
  class Activity
    class Circuit
      # Pipeline is a Circuit which, in #resolve, simply ignores the actual signal
      # when looking up the next step.
      class Pipeline < Circuit
        def resolve(last_task_id, signal)
          next_task_id = map[last_task_id][nil]

          config[next_task_id]
        end
      end
    end # Circuit
  end
end
