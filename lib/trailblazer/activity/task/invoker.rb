 module Trailblazer
  class Activity
    class Task
      module Invoker
        class LibInterface
          def self.call(task, ctx, flow_options, signal, **)
            # puts "@@@@@ #{ctx.inspect}, LIB  #{lib_ctx}"
            task.(ctx, flow_options, signal, **ctx) # DISCUSS: do we want circuit_options?
          end

          class InstanceMethod
            def self.call(task, ctx, flow_options, signal, **)
              exec_context = ctx.fetch(:exec_context)

              exec_context.send(task, ctx, flow_options, signal, **ctx)
            end
          end
        end

        # class CircuitInterface
        #   def self.call(task, ctx, lib_ctx, signal)
        #     task.(ctx, lib_ctx, signal)
        #   end

        #   class InstanceMethod # DISCUSS: should we remove this? users can use a callable if they really need the circuit interface.
        #     def self.call(task, ctx, lib_ctx, circuit_options, _) # DISCUSS: hm, do we need this?
        #       exec_context = circuit_options.fetch(:exec_context)
        #       # raise "remove me"
        #       exec_context.send(task, ctx, lib_ctx, circuit_options, **ctx.to_h) # TODO: how to add kwargs for Rescue.
        #       # FIXME: we're NOT passing circuit_options to instance method?
        #     end
        #   end
        # end

        # The step interface is only used on the application level.
        class StepInterface
          def self.call(task, ctx, flow_options, _, **)
            target_ctx = flow_options[:application_ctx]

            result = run_step(task, target_ctx, **ctx)

            ctx[:value] = result

            return ctx, flow_options, nil # DISCUSS: value.
          end

          def self.run_step(task, target_ctx, _)
            task.(target_ctx, **target_ctx.to_h)
          end

          class InstanceMethod < StepInterface
            def self.run_step(task, target_ctx, exec_context:, **)
              exec_context.send(task, target_ctx, **target_ctx.to_h)
            end
          end
        end # StepInterface
      end
    end # Task

  end
end
