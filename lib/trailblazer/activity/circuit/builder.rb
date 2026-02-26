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

          Activity::Circuit::Pipeline.build(
            flow_map: map,
            config:   config,
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

        # TODO: location, should that be Activity?
        # A taskWrap is just a Pipeline with a mandatory element {call_task}.
        # @private
        def self.TaskWrap(*nodes_options)
          raise "no call_task provided!" unless nodes_options.find { |(id, _)| id == :"task_wrap.call_task" }

          Pipeline(*nodes_options)
        end

        # DISCUSS: should that sit in Activity? it's higher level than Circuit.
        module Step
          def self.InstanceMethod(method_name)
            Builder.Pipeline(
              [:invoke_instance_method, method_name, Task::Invoker::StepInterface::InstanceMethod], # FIXME: we're currenly assuming that exec_context is passed down.
              [:compute_binary_signal, Circuit::Step::ComputeBinarySignal, Task::Invoker::LibInterface],
            )
          end
        end
      end # Builder
    end
  end
end
