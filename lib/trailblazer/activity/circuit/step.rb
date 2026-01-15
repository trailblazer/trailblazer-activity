module Trailblazer
  class Activity
    # Circuit::TaskAdapter:   Uses Circuit::Step to translate incoming, and returns a circuit-interface
    #                 compatible return set.
    class Circuit
      def self.Task(filter_with_circuit_interface)
        Task.build(filter_with_circuit_interface)
      end

      # DISCUSS: currently, a Task instance always wraps an InstanceMethod.
      class Task
        class InstanceMethod < Struct.new(:task_instance_method_wrap)
          def call(ctx, flow_options, circuit_options, **kwargs)
            callable = task_instance_method_wrap.(ctx, flow_options, circuit_options, **kwargs)  #this step is specific to instance methods

            callable.(ctx, flow_options, circuit_options, **kwargs) # This is how any Task is invoked!
            # return
          end
        end

        # here, we decide what needs wrapping.
        def self.build(user_filter_with_circuit_interface)
          if user_filter_with_circuit_interface.is_a?(Symbol)
            # TODO: Let Option/Filter::InstanceMethod do that
            return Task::InstanceMethod::new(Callable::InstanceMethod.new(user_filter_with_circuit_interface))
          end

          # No need for any wrapping.
          return user_filter_with_circuit_interface
        end
        module Callable
          # TODO: this is generic, applies to Task and Step!!!
          class InstanceMethod < Struct.new(:filter)
            # This is one "step" for the Task/Step adapter, specific to instance methods,
            # and it allows calling the returned callable as if it was a MyHandler.
            # RUNTIME, THIS IS EXECUTED BY THE TASK/STEP instance.
            def call(ctx, flow_options, circuit_options, **kws)
              exec_context  = circuit_options.fetch(:exec_context)
              # That was my first idea, but it doesn't play if devs would use dispatching based on {#method_missing}.
              # callable      = exec_context.method(filter) # this is the actual change from Option thinking.

              callable = ->(*args, **kws) { exec_context.send(filter, *args, **kws) } # this should be generic, so we can use it with Task and Step interfaces (and ext-ci)

  # tHE IDEA here is that the only difference to a raw filter is that we extract the "callable" before we do the rest
  # (invoking with whatever interface, interpreting the result etc)
            end
          end
        end # Callable
      end

      # Single-entry point to build a step with a circuit interface that is internally
      # calling a user code chunk with a step interface (ctx, **ctx).
      #
      # In TRB 2.1, this used to sit in the Trailblazer::Option gem, but never really made sense
      # as we're building
#       def self.Step(user_filter_with_step_interface, option: nil, **options)
# raise if option # FIXME: remove once this is sorted.

#         options = options.merge(instance_method: true) if user_filter_with_step_interface.is_a?(Symbol)

#         Step.build(user_filter_with_step_interface, **options)
#       end

      def self.Step(filter_with_step_interface, **options)
        Step___.build(filter_with_step_interface, **options)
      end

      class Step___ < Struct.new(:user_filter, :binary?)
        module Binary
          # overriding Step#call.
          def call(ctx, flow_options, circuit_options)
            result = super
            Binary.compute_signal(ctx, flow_options, result) # returns circuit interface.
          end

          def self.compute_signal(ctx, flow_options, result)
            signal = Binary.binary_signal_for(result, Activity::Right, Activity::Left)

            return ctx, flow_options, signal
          end

          # Translates the return value of the user step into a valid signal.
          # Note that it passes through subclasses of {Activity::Signal}.
          def self.binary_signal_for(result, on_true, on_false)
            if result.is_a?(Class) && result < Activity::Signal
              result
            else
              result ? on_true : on_false
            end
          end
        end

        class Binary___ < Step___
          include Binary
        end

        def self.build(filter_with_step_interface, binary: true)
          step_class = Step___
          if binary
            step_class = Binary___
          end

          if filter_with_step_interface.is_a?(Symbol)
            step_class = InstanceMethod

            if binary
              step_class = InstanceMethod::Binary___
            end
            # TODO: Let Option/Filter::InstanceMethod do that
            return step_class.new(filter_with_step_interface, Task::Callable::InstanceMethod.new(filter_with_step_interface), binary)
          end

          return step_class.new(filter_with_step_interface, binary)
        end

        class InstanceMethod < Struct.new(:user_filter, :task_instance_method_wrap, :binary?)
          class Binary___ < InstanceMethod
            include Binary
          end

          def call(ctx, flow_options, circuit_options) # FIXME: applies only to {:instance_method}
            callable = task_instance_method_wrap.(ctx, flow_options, circuit_options) # DISCUSS: copied from {Task#call}.

            result   = Step___.invoke_callable_with_step_interface(callable, ctx, flow_options, circuit_options) # FIXME: from here downwards, it's generic!

            return result
          end
        end

        def call(ctx, flow_options, circuit_options)
          result = Step___.invoke_callable_with_step_interface(user_filter, ctx, flow_options, circuit_options)

          return result
        end

        def self.invoke_callable_with_step_interface(callable, ctx, flow_options, circuit_options)
          _result = callable.(ctx, **ctx.to_h) # This is how any Step should be called!
        end

# raise "get rid of the if, with four subclasses"
        # FIXME: every step needs wrapping.
        # FIXME: we don't handle binary and raw handler here, yet

      end

      # {Step#call} translates the incoming circuit-interface to the step-interface,
      # and returns the return value of the user's callable.
      class Step
        def self.build(callable_with_step_interface, option: false, instance_method: false, binary: nil)
          # This will result in a step being wrapped in a Binary step.
          binary = Step::Binary if binary === true

          circuit_step =
            # TODO: should we detect here if Option wrapping is needed?
            if instance_method
              # currently, this is only used for {:instance_method} filters.
              Step::Option.new(Activity::Option::InstanceMethod.new(callable_with_step_interface))
            else
              Step.new(callable_with_step_interface)
            end

          if binary
            circuit_step = binary.new(circuit_step) # DISCUSS: i hate wrapping, but we cannot use an Activity-based approach, yet.
          end

          return circuit_step
        end

        def initialize(step)
          @step = step
        end

        # NOTE: step interface is (ctx, **kwargs) and returns a single value (the "signal").

        # Translate the circuit interface to the step's step-interface.
        # We treat the return value as a "signal".
        def call(ctx, flow_options, circuit_options)
          result = @step.(ctx, **ctx.to_hash) # call @step with step interface.

          # DISCUSS: in an immutable environment we should return the ctx from the step.
          # in an additional "layer" we could treat the result as something coming from return Result(ctx, Success|true),
          # and then return the new ctx here. it's much more convenient letting OP steps alter the ctx directly, though.

          return ctx, flow_options, result
        end

        # DISCUSS: here, we have knowledge about how an Option::InstanceMethod is being called, and what it
        #          returns. here, we assume that it's always one particular value. what if we want to call a @step with a circuit interface?
        #
        # In {Step::Option}, {@step} is expected to be wrapped in a {Trailblazer::Option}.
        # To remember: when calling an Option instance, you need to pass {:keyword_arguments} explicitly,
        # because of beautiful Ruby 2.5 and 2.6.
        #
        # This is often needed for "decider" chunks where the user can run either a method or a callable
        # but you only want back the return value, not a Binary circuit-interface return set.
        class Option < Step
          def call(ctx, flow_options, circuit_options)
            # Invoke Option::InstanceMethod#call():
            result = @step.(ctx, keyword_arguments: ctx.to_hash, **circuit_options) # {circuit_options} contain {:exec_context}.

            return ctx, flow_options, result
          end
        end

        # A Binary instance wraps a Step instance and adds logic for processing the result "signal".
        class Binary < Step
          def call(ctx, flow_options, circuit_options)
            ctx, flow_options, result = @step.(ctx, flow_options, circuit_options)

            # Return an appropriate signal which direction to go next.
            ctx, flow_options, signal = compute_signal(ctx, flow_options, result)

            return ctx, flow_options, signal
          end

          def compute_signal(ctx, flow_options, result)
            signal = Binary.binary_signal_for(result, Activity::Right, Activity::Left)

            return ctx, flow_options, signal
          end

          # Translates the return value of the user step into a valid signal.
          # Note that it passes through subclasses of {Activity::Signal}.
          def self.binary_signal_for(result, on_true, on_false)
            if result.is_a?(Class) && result < Activity::Signal
              result
            else
              result ? on_true : on_false
            end
          end
        end
      end # Step

      # FIXME:, docs: TaskAdapter instance wraps a user code chunk with a circuit interface, the return value of the user code is arbitrary and we translate it to a binary signal.

      # FIXME: deprecate TaskAdapter

      #   # FIXME: this method sucks as it shows the wrong name.
      #   def inspect # TODO: make me private!
      #     # return super
      #     user_step = @circuit_step.instance_variable_get(:@user_proc) # DISCUSS: to we want Step#to_h?

      #     %(#<Trailblazer::Activity::TaskBuilder::Task user_proc=#{Trailblazer::Activity::Introspect.render_task(user_step)}>)
      #   end
      #   alias_method :to_s, :inspect
      # end
    end # Circuit
  end # Activity
end
