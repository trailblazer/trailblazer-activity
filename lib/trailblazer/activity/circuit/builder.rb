module Trailblazer
  class Activity
    class Circuit
      # Helpers for those who don't like or have a DSL :D
      module Builder
        # Pipeline is just another circiut, where each step has only one output.
        def self.Pipeline(*task_cfgs, **default_circuit_options)
          # task_cfgs = task_cfgs.collect do |id, task, invoker = Trailblazer::Activity::Task::Invoker::CircuitInterface, circuit_options = {}|
          task_cfgs = task_cfgs.collect do |id, task, invoker = Activity::Task::Invoker::LibInterface::InstanceMethod____withSignal_FIXME, circuit_options = {}|
            [
              id,
              task,
              invoker,
              default_circuit_options.merge(circuit_options)
            ]
          end

          map = task_cfgs.collect.with_index do |(id, _), i|
            next_task = task_cfgs[i + 1]
            signal = nil

            [
              id,
              {signal => next_task ? next_task[0] : nil} # FIXME: don't link last task at all!
            ]
          end.to_h

          config = task_cfgs.collect do |(id, task, invoker, options)|
            [id, [id, task, invoker, options]]
          end.to_h

          Activity::Circuit::Pipeline.new(
            map:            map,
            start_task_id:  config.keys[0],
            termini:        [config.keys[-1]],
            config:         config,
          )
        end

        def self.Circuit(*task_cfgs, termini:)

        # TODO: use code from above.
          task_cfgs = task_cfgs.collect do |id, task, invoker = Trailblazer::Activity::Task::Invoker::CircuitInterface, circuit_options = {}, options = {}|
            # outputs = options[:outputs] || {Activity::Right => } # defaults to {nil}.

            [
              id, task, invoker, circuit_options, options
            ]
          end

        # FIXME: use code from above.
          config = task_cfgs.collect do |(id, task, invoker, options)|
            [id, [id, task, invoker, options]]
          end.to_h

          outputs = termini.collect do |semantic|
            [semantic, config[semantic][1]]
          end.to_h

          map = task_cfgs.collect do |id, task, invoker, circuit_options, connections|
            [id, connections]
          end.to_h

          return Activity::Circuit.new(
              map:            map,
              start_task_id:  config.keys[0],
              termini:        termini,
              config:         config,
            ),
            outputs
        end
      end # Builder
    end
  end
end
