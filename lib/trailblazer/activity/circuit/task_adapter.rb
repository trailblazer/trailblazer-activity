module Trailblazer
  class Activity
    #
    # Circuit::Step:          Only translates the incoming circuit-interface to step-interface.
    # Circuit::Step::Option:  Only translates the incoming circuit-interface to step-interface.
    #                         Internally, call a Trailblazer::Option object.
    # Circuit::TaskAdapter:   Uses Circuit::Step to translate incoming, and returns a circuit-interface
    #                 compatible return set.
    class Circuit# step and circuit_step are different!!
      def self.Step(callable_with_step_interface, option: false)
        if option
          return Step::Option.new(Trailblazer::Option(callable_with_step_interface), callable_with_step_interface)
        end

        Step.new(callable_with_step_interface, callable_with_step_interface) # DISCUSS: maybe we can ditch this, only if performance is cool here, but where would we use that?
      end

      # {Step#call} returns a return value. It is *not* circuit-interface compatible (by design).
      class Step
        def initialize(step, user_proc, **)
          @step            = step
          @user_proc       = user_proc
        end

        # Translate the circuit interface to the step's step-interface. However,
        # this only translates the calling interface, not the returning.
        def call((ctx, flow_options), **circuit_options)
          result = @step.(ctx, **ctx.to_hash)
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

      # Always exposes circuit-interface, a {TaskAdapter} instance can be used directly in a {Circuit}.
      class TaskAdapter
        def self.for_step(step, binary: true, **options_for_step)
          circuit_step = Circuit.Step(step, **options_for_step)

          new(circuit_step)
        end

        # @param circuit_step Exposes a Circuit::Step.call([ctx, flow_options], **circuit_options) interface
        def initialize(circuit_step, **)
          @circuit_step = circuit_step
        end

        def call((ctx, flow_options), **circuit_options)
          result, ctx = @circuit_step.([ctx, flow_options], **circuit_options)

          # Return an appropriate signal which direction to go next.
          signal = TaskAdapter.binary_signal_for(result, Activity::Right, Activity::Left)

          return signal, [ctx, flow_options]
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

        def inspect # TODO: make me private!
          user_step = @circuit_step.instance_variable_get(:@user_proc) # DISCUSS: to we want Step#to_h?

          %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=#{Trailblazer::Activity::Introspect.render_task(user_step)}>}
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

    class Pipeline # DISCUSS: move this to {task_wrap/pipeline.rb}?
      # Implements adapter for a callable in a Pipeline.
      class TaskAdapter < Circuit::TaskAdapter
        def self.for_step(callable, **)
          circuit_step = Circuit.Step(callable, option: false) # Since we don't have {:exec_context} in Pipeline, Option doesn't make much sense.

          TaskAdapter.new(circuit_step) # return a {Pipeline::TaskAdapter}
        end

        def call(wrap_ctx, args)
          _result, _new_wrap_ctx = @circuit_step.([wrap_ctx, args]) # For funny reasons, the Circuit::Step's call interface is compatible to the Pipeline's.

          # DISCUSS: we're mutating wrap_ctx, that's the whole point of this abstraction (plus kwargs).

          return wrap_ctx, args
        end
      end
    end # Pipeline

    # TODO: remove when we drop compatibility.
    module TaskBuilder
      def self.Binary(user_proc)
        warn %{[Trailblazer] Activity::TaskBuilder is deprecated. Please use the TaskAdapter API: # FIXME}

        Activity::Circuit::TaskAdapter.for_step(user_proc, option: true)
      end
    end
    # deprecate_constant :TaskBuilder
    # TaskBuilder::Task = Circuit::TaskAdapter::Step
  end # Activity
end
