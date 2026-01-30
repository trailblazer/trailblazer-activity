module Trailblazer
  class Activity
    # Circuit::TaskAdapter:   Uses Circuit::Step to translate incoming, and returns a circuit-interface
    #                 compatible return set.
    class Circuit
      def self.Task(filter_with_circuit_interface)
        Task.build(filter_with_circuit_interface)
      end

      class Processor #< Pipeline
        def self.call(pipeline, ctx, flow_options, circuit_options, signal = nil, lib_ctx)
          pipeline.to_a.each do |(_id, task)|
            ctx, flow_options, signal, lib_ctx = task.(ctx, flow_options, circuit_options, signal, lib_ctx, **lib_ctx)
          end

          return ctx, flow_options, signal, lib_ctx # FIXME: experimenting here.
        end
      end

      class Task___Activity# < Activity::Railway # TODO: naming.
        module Generic # DISCUSS: rename back to {Callable}?
          # TODO: this is generic, applies to Task and Step!!!
          class InstanceMethod
            # This is one "step" for the Task/Step adapter, specific to instance methods,
            # and it allows calling the returned callable as if it was a MyHandler.
            # RUNTIME, THIS IS EXECUTED BY THE TASK/STEP instance.
            def self.compute_callable(ctx, flow_options, circuit_options, method_name, lib_ctx, **)
              exec_context  = circuit_options.fetch(:exec_context)
              # That was my first idea, but it doesn't play if devs would use dispatching based on {#method_missing}.
              # callable      = exec_context.method(method_name) # this is the actual change from Option thinking.

              callable = ->(*args, **kws) { exec_context.send(method_name, *args, **kws) } # this should be generic, so we can use it with Task and Step interfaces (and ext-ci)

  # tHE IDEA here is that the only difference to a raw filter is that we extract the "callable" before we do the rest
  # (invoking with whatever interface, interpreting the result etc)

              return ctx, flow_options, callable, lib_ctx
            end
          end

          def self.invoke_callable(ctx, flow_options, circuit_options, callable, lib_ctx, callable_keyword_arguments: {}, **)
            # DISCUSS: we currently need {callable_keyword_arguments} only in one spot (if I remember correctly, that's the Rescue handler and :exception)

            ctx, flow_options, signal = callable.(ctx, flow_options, circuit_options, **callable_keyword_arguments) # This is how any Task is invoked!

            return ctx, flow_options, signal, lib_ctx
          end
        end # Generic

        InstanceMethod = Activity.Pipeline(
          compute_callable: Generic::InstanceMethod.method(:compute_callable),
          invoke_callable: Generic.method(:invoke_callable), # FIXME: is this generic or Task-specific? we don't use it for Step?
        )
      end

      # DISCUSS: currently, a Task instance always wraps an InstanceMethod.
      class Task
        class InstanceMethod < Struct.new(:task_instance_method_wrap)
          def call(ctx, flow_options, circuit_options, **kwargs)
            callable = task_instance_method_wrap.(ctx, flow_options, circuit_options, **kwargs)  #this step is specific to instance methods

            callable.(ctx, flow_options, circuit_options, **kwargs) # This is how any Task is invoked!
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



      class Step___ < Struct.new(:activity, :user_filter)
        def self.invoke_callable_with_step_interface(ctx, flow_options, circuit_options, callable, lib_ctx, **)

          result = callable.(ctx, **ctx.to_h) # This is how any Step should be called!

          return ctx, flow_options, result, lib_ctx
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


          def self.___compute_signal(ctx, flow_options, circuit_options, result, lib_ctx, **)
            # we're a step, {result} is always a "boolean".
            signal = Binary.binary_signal_for(result, Activity::Right, Activity::Left)

            return ctx, flow_options, signal, lib_ctx
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
        Step___Activity___Binary = Activity::Adds.(
          Step___Activity,                      # "inherit" from Step___Activity
          [Binary.method(:___compute_signal), id: :compute_signal, append: nil]
        )

        def self.build(filter_with_step_interface, binary: true)
          step =
            if filter_with_step_interface.is_a?(Symbol)
              # generic_instance_method_caller = Task::Generic::InstanceMethod.new(filter_with_step_interface)
              # Step___::InstanceMethod.new(generic_instance_method_caller)
              if binary
                Step___.new(Step___Activity___InstanceMethod___Binary, filter_with_step_interface)
              else
                Step___.new(Step___Activity___InstanceMethod, filter_with_step_interface)
              end
            else
              if binary
                Step___.new(Step___Activity___Binary, filter_with_step_interface)
              else
                Step___.new(Step___Activity, filter_with_step_interface)
              end
            end

          return step
        end

        def call(ctx, flow_options, circuit_options)
          # ctx, _flow_options, signal =
          Processor.(
            activity,
            ctx,
            flow_options,
            circuit_options,
            user_filter,
            {} # library_ctx
          )
        end
      end


      # FIXME:, docs: TaskAdapter instance wraps a user code chunk with a circuit interface, the return value of the user code is arbitrary and we translate it to a binary signal.

    end # Circuit
  end # Activity
end
