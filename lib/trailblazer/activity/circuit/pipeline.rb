module Trailblazer
  class Activity
    class Circuit
      # Pipeline is a Circuit which, in #resolve, simply ignores the actual signal
      # when looking up the next step.
      class Pipeline < Circuit
        def resolve(current_task, signal)
          current_task_id = current_task[0]

          next_task_id = map[current_task_id][nil]

          return config[next_task_id]
        end
      end
    end # Circuit
  end
end
