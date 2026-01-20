module Trailblazer
  class Activity
    # Circuit::TaskAdapter:   Uses Circuit::Step to translate incoming, and returns a circuit-interface
    #                 compatible return set.
    class Circuit
      def self.Task(filter_with_circuit_interface)
        Task.build(filter_with_circuit_interface)
      end

      class Task___Activity# < Activity::Railway # TODO: naming.
      # DISCUSS: make the third argument pass-through?
      #   def self.call(pipeline, ctx, flow_options, circuit_options = {})
      #   runner = circuit_options[:runner]

      #   pipeline.to_a.each do |(_id, task)|
      #     ctx, flow_options = runner.(task, ctx, flow_options, circuit_options)
      #   end

      #   return ctx, flow_options # FIXME: experimenting here.
      # end


        module Generic # DISCUSS: rename back to {Callable}?
          # TODO: this is generic, applies to Task and Step!!!
          class InstanceMethod
            # This is one "step" for the Task/Step adapter, specific to instance methods,
            # and it allows calling the returned callable as if it was a MyHandler.
            # RUNTIME, THIS IS EXECUTED BY THE TASK/STEP instance.
            def self.compute_callable(ctx, flow_options, circuit_options, **kws)
              exec_context  = circuit_options.fetch(:exec_context)
              # That was my first idea, but it doesn't play if devs would use dispatching based on {#method_missing}.
              # callable      = exec_context.method(method_name) # this is the actual change from Option thinking.

              method_name = ctx.fetch(:method_name)

              callable = ->(*args, **kws) { exec_context.send(method_name, *args, **kws) } # this should be generic, so we can use it with Task and Step interfaces (and ext-ci)

  # tHE IDEA here is that the only difference to a raw filter is that we extract the "callable" before we do the rest
  # (invoking with whatever interface, interpreting the result etc)
              ctx[:callable] = callable

              return ctx, flow_options, Trailblazer::Activity::Right
            end
          end

          def self.invoke_callable(ctx, flow_options, circuit_options, **kwargs)
            callable = ctx[:callable]
            application_ctx = ctx[:application_ctx]

            result = callable.(application_ctx, flow_options, circuit_options, **kwargs) # This is how any Task is invoked!

            ctx[:result] = result
            return ctx, flow_options, Trailblazer::Activity::Right
          end
        end # Generic





        # class InstanceMethod  #< Activity::Railway
          # step # DISCUSS: whoopsi, we don't have the DSL here :D
        # end
        InstanceMethod = Activity.Pipeline(
          compute_callable: Generic::InstanceMethod.method(:compute_callable),
          invoke_callable: Generic.method(:invoke_callable),
        )
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
            return Task::InstanceMethod::new(Generic::InstanceMethod.new(user_filter_with_circuit_interface))
          end

          # No need for any wrapping.
          return user_filter_with_circuit_interface
        end

        module Generic # DISCUSS: rename back to {Callable}?
          # TODO: this is generic, applies to Task and Step!!!
          class InstanceMethod < Struct.new(:method_name)
            # This is one "step" for the Task/Step adapter, specific to instance methods,
            # and it allows calling the returned callable as if it was a MyHandler.
            # RUNTIME, THIS IS EXECUTED BY THE TASK/STEP instance.
            def call(ctx, flow_options, circuit_options, **kws)
              exec_context  = circuit_options.fetch(:exec_context)
              # That was my first idea, but it doesn't play if devs would use dispatching based on {#method_missing}.
              # callable      = exec_context.method(method_name) # this is the actual change from Option thinking.

              callable = ->(*args, **kws) { exec_context.send(method_name, *args, **kws) } # this should be generic, so we can use it with Task and Step interfaces (and ext-ci)

  # tHE IDEA here is that the only difference to a raw filter is that we extract the "callable" before we do the rest
  # (invoking with whatever interface, interpreting the result etc)
            end
          end
        end # Generic
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
        def self.invoke_callable_with_step_interface(ctx, flow_options, circuit_options)
          callable = ctx[:callable]

          application_ctx = ctx[:application_ctx]

          _result = callable.(application_ctx, **application_ctx.to_h) # This is how any Step should be called!

          ctx[:result] = _result

          return ctx, flow_options, Trailblazer::Activity::Right
        end

        class Binary < Struct.new(:step)
          def call(ctx, flow_options, circuit_options)
            result = step.call(ctx, flow_options, circuit_options) # whatever step is

            Binary.compute_signal(ctx, flow_options, result) # returns circuit interface.
          end

          def self.compute_signal(ctx, flow_options, result)
            signal = Binary.binary_signal_for(result, Activity::Right, Activity::Left)

            return ctx, flow_options, signal
          end


          def self.___compute_signal(ctx, flow_options, circuit_options)
            result = ctx.fetch(:result)

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

        Step___Activity = Activity.Pipeline(
          invoke_callable: Step___.method(:invoke_callable_with_step_interface),
        )
        Step___Activity___InstanceMethod = Activity::Adds.(
          Step___Activity,                      # "inherit" from Step___Activity.
          [Task___Activity::Generic::InstanceMethod.method(:compute_callable), id: :compute_callable, prepend: :invoke_callable]
        )
        Step___Activity___InstanceMethod___Binary =  Activity::Adds.(
          Step___Activity___InstanceMethod,                      # "inherit" from Step___Activity___InstanceMethod.
          [Binary.method(:___compute_signal), id: :compute_signal, append: nil]
        )

        def self.build(filter_with_step_interface, binary: true)
          step =
            if filter_with_step_interface.is_a?(Symbol)
              generic_instance_method_caller = Task::Generic::InstanceMethod.new(filter_with_step_interface)
              Step___::InstanceMethod.new(generic_instance_method_caller)
            else
              Step___.new(filter_with_step_interface)
            end

          if binary
            step = Step___::Binary.new(step)
          end

          return step
        end

        # def self.invoke_callable_with_step_interface(callable, ctx, flow_options, circuit_options)
        # Generic #call that invokes callable with step interface.
        def call(ctx, flow_options, circuit_options)
          _result = user_filter.(ctx, **ctx.to_h) # This is how any Step should be called!
        end

        class InstanceMethod < Struct.new(:generic_instance_method_caller)
          def call(ctx, flow_options, circuit_options) # FIXME: applies only to {:instance_method}
            callable = generic_instance_method_caller.(ctx, flow_options, circuit_options) # DISCUSS: copied from {Task#call}.

            # Problem: we only know the callable at runtime!
            # We also don't want to expose private affairs of the Step implementation here, here we
            # want to use its public API.
            step = Step___.new(callable) # FIXME: using the Wrapping approach shows its flaws here.
            result = step.(ctx, flow_options, circuit_options)

            return result
          end
        end
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
