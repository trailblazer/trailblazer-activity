module Trailblazer
  class Activity
    class Circuit
      def self.Step(callable_with_step_interface, option: false)
        if option
          return Step::Option.new(Trailblazer::Option(callable_with_step_interface), callable_with_step_interface)
        end

        Step.new(callable_with_step_interface, callable_with_step_interface) # DISCUSS: maybe we can ditch this, only if performance is cool here, but where would we use that?
      end

      # {Step#call} returns a return value. It is *not* circuit-interface compatible (by design).
      class Step # DISCUSS: Will WE NEED/USE this anywhere? we normally wrap everything into an Option, anyway.
        def initialize(step, user_proc, **)
          @step            = step
          @user_proc       = user_proc
        end

        # Execute the user step with TRB's kw args.
        # {@step} is/implements {Trailblazer::Option} interface.
        def call((ctx, flow_options), **circuit_options)
          result = @step.call(ctx, **ctx.to_hash)
          # in an immutable environment we should return the ctx from the step.
          return result, ctx
        end

        # In {Step::Option}, {@step} is expected to be wrapped in an {Option}.
        # To remember: when calling an Option instance, you need to pass {:keyword_arguments} explicitely, because, Ruby 2.5 and 2.6.
        #
        # This is often needed for "decider" chunks where the user can run either a method or a callable
        # but you only want back the return value, not a Binary circuit-interface return set.
        class Option < Step
          def call((ctx, _flow_options), **circuit_options)
            result = @step.(ctx, keyword_arguments: ctx.to_hash, **circuit_options) # circuit_options contains :exec_context.
            # in an immutable environment we should return the ctx from the step.
            return result, ctx
          end
        end
      end


        # # Invoke the original {user_proc} that is wrapped in an {Option()}.
        # private def call_option(step_with_option_interface, (ctx, _flow_options), **circuit_options)
        #   step_with_option_interface.(ctx, keyword_arguments: ctx.to_hash, **circuit_options) # circuit_options contains :exec_context.
        # end

      # Always exposes circuit-interface.
        # that can be used directly in a {Circuit}.
      class Task
        def self.for_step(step, binary: true, **options_for_step)
          circuit_step = Circuit.Step(step, **options_for_step)

          new(circuit_step)
        end

        # @param circuit_step Exposes a Circuit::Step.call([ctx, flow_options], **circuit_options) interface
        def initialize(circuit_step, **)
          @circuit_step = circuit_step
          # @user_proc       = user_proc
        end

        def call((ctx, flow_options), **circuit_options)
          result, ctx = @circuit_step.([ctx, flow_options], **circuit_options)

          # Return an appropriate signal which direction to go next.
          signal = Task.binary_signal_for(result, Activity::Right, Activity::Left)

          return signal, [ctx, flow_options]
        end

        # every step is wrapped by this proc/decider. this is executed in the circuit as the actual task.
        # Step calls step.(options, **options, flow_options)
        # Output signal binary: true=>Right, false=>Left.
        # Passes through all subclasses of Direction.~~~~~~~~~~~~~~~~~

        def self.Binary(user_proc, adapter_class: Step, **options)
raise "implement me for compat"
        end

        # Translates the return value of the user step into a valid signal.
        # Note that it passes through subclasses of {Signal}.
        def self.binary_signal_for(result, on_true, on_false)
          if result.is_a?(Class) && result < Activity::Signal
            result
          else
            result ? on_true : on_false
          end
        end

        def inspect # TODO: make me private!
          %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=#{Trailblazer::Activity::Introspect.render_task(@user_proc)}>}
        end
        alias_method :to_s, :inspect


        # Task::Circuit::Adapter::AssignVariable
        # Run {user_proc} with "step interface" and assign its return value to ctx[@variable_name].
        # @private
        # This is experimental.
        # class AssignVariable < Step
        #   def initialize(*args, variable_name:, **options)
        #     super(*args, **options)

        #     # name of the ctx variable we want to assign the return_value of {user_proc} to.
        #     @variable_name = variable_name
        #   end

        #   def call_option(task_with_option_interface, (ctx, flow_options), **circuit_options)
        #     return_value = super # Adapter.call

        #     ctx[@variable_name] = return_value
        #   end
        # end
      end
    end # Circuit

    # TODO: deprecate
    # TaskBuilder       = Circuit::TaskAdapter
    # TaskBuilder::Task = Circuit::TaskAdapter::Step
  end # Activity
end
