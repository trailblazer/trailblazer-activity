module Trailblazer
  class Activity
    class Circuit
      # Helpers for those who don't like or have a DSL :D
      module Builder
        # Pipeline is just another circiut, where each step has only one output.
        def self.Pipeline(*task_cfgs)
          task_cfgs = task_cfgs.collect do |id, task, invoker = Trailblazer::Activity::Task::Invoker::CircuitInterface, circuit_options = {}, options = {}|
            signal = options[:signal] # defaults to {nil}.

            [
              id, task, invoker, circuit_options, signal
            ]
          end

          map = task_cfgs.collect.with_index do |(id, _, _, _, signal), i|
            next_task = task_cfgs[i + 1]

            [
              id,
              {signal => next_task ? next_task[0] : nil} # FIXME: don't link last task at all!
            ]
          end.to_h

          config = task_cfgs.collect do |(id, task, invoker, options)|
            [id, [id, task, invoker, options]]
          end.to_h

          Trailblazer::Activity::Circuit.new(
            map:            map,
            start_task_id:  config.keys[0],
            termini:        [config.keys[-1]],
            config:         config,
          )
        end

      end
    end
  end
end
