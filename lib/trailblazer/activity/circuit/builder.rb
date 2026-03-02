module Trailblazer
  class Activity
    class Circuit
      # Helpers for those who don't like or have a DSL :D
      module Builder
        # Pipeline is just another circiut, where each step has only one output.
        def self.Pipeline(*task_cfgs, **default_circuit_options)
          raise if default_circuit_options.any?
          # task_cfgs = task_cfgs.collect do |id, task, invoker = Trailblazer::Activity::Task::Invoker::CircuitInterface, circuit_options = {}|
          task_cfgs = task_cfgs.collect do |id, task, invoker = Activity::Task::Invoker::LibInterface::InstanceMethod, merge_to_lib_ctx = {}, node_processor = nil, node_processor_options = {}|
            if node_processor.nil?
              node_processor = merge_to_lib_ctx.any? ? Node::Processor::Scoped : Node::Processor # FIXME: test me
            end

            [
              id,
              task,
              invoker,
              merge_to_lib_ctx,
              node_processor,
              node_processor_options,
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

          config = task_cfgs.collect do |(id, task, invoker, merge_to_lib_ctx, node_processor, node_processor_options)|
            [id, [id, task, invoker, merge_to_lib_ctx, node_processor, node_processor_options]]
          end.to_h

          Activity::Circuit::Pipeline.build(
            flow_map: map,
            config:   config,
          )
        end

        def self.Circuit(*task_cfgs, termini:)
        # TODO: use code from above.
          task_cfgs = task_cfgs.collect do |id, task, invoker = Trailblazer::Activity::Task::Invoker::CircuitInterface, merge_to_lib_ctx = {}, node_processor = nil, node_processor_options = {}, connections = {}|
            # outputs = options[:outputs] || {Activity::Right => } # defaults to {nil}.
            # if node_processor.nil?
            #   node_processor = merge_to_lib_ctx.any? ? Node::Processor::Scoped : Node::Processor # FIXME: test me
            # end # FIXME! redundant!

            [
              id, task, invoker, merge_to_lib_ctx, node_processor, node_processor_options, connections
            ]
          end

        # FIXME: use code from above.
          config = task_cfgs.collect do |a,b,c,d,e,f|
            [a, [a,b,c,d,e,f]]
          end.to_h

          outputs = termini.collect do |semantic|
            [semantic, config[semantic][1]]
          end.to_h

          map = task_cfgs.collect do |id, b,c,d,e,f,connections|
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

          def self.Callable(callable)
            Builder.Pipeline(
              [:invoke_callable, callable, Trailblazer::Activity::Task::Invoker::StepInterface],
              [:compute_binary_signal, Trailblazer::Activity::Circuit::Step::ComputeBinarySignal, Trailblazer::Activity::Task::Invoker::LibInterface],
            )
          end
        end
      end # Builder
    end
  end
end
