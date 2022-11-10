module Trailblazer
  class Activity
    # Circuit::TaskAdapter:   Uses Circuit::Step to translate incoming, and returns a circuit-interface
    #                 compatible return set.
    class Circuit
      # Create a `Circuit::Step` instance. Mostly this is used inside a `TaskAdapter`.
      #
      # @param    [callable_with_step_interface] Any kind of callable object or `:instance_method` that receives
      #   a step interface.
      # @param    [:option] If true, the user's callable argument is wrapped in `Trailblazer::Option`.
      # @return   [Circuit::Step, Circuit::Step::Option] Returns a callable circuit-step.
      # @see      https://trailblazer.to/2.1/docs/activity#activity-internals-step-interface
      def self.Step(callable_with_step_interface, option: false)
        if option
          return Step::Option.new(Trailblazer::Option(callable_with_step_interface), callable_with_step_interface)
        end

        Step.new(callable_with_step_interface, callable_with_step_interface) # DISCUSS: maybe we can ditch this, only if performance is cool here, but where would we use that?
      end

      # {Step#call} translates the incoming circuit-interface to the step-interface,
      # and returns the return value of the user's callable. By design, it is *not* circuit-interface compatible.
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

        # In {Step::Option}, {@step} is expected to be wrapped in a {Trailblazer::Option}.
        # To remember: when calling an Option instance, you need to pass {:keyword_arguments} explicitely,
        # because of beautiful Ruby 2.5 and 2.6.
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

      class TaskAdapter
        # Returns a `TaskAdapter` instance always exposes the complete circuit-interface,
        # and can be used directly in a {Circuit}.
        #
        # @note     This used to be called `TaskBuilder::Task`.
        # @param    [step] Any kind of callable object or `:instance_method` that receives
        #   a step interface.
        # @param    [:option] If true, the user's callable argument is wrapped in `Trailblazer::Option`.
        # @return   [TaskAdapter] a circuit-interface compatible object to use in a `Circuit`.
        def self.for_step(step, binary: true, **options_for_step)
          circuit_step = Circuit.Step(step, **options_for_step)

          new(circuit_step)
        end

        # @param [circuit_step] Exposes a Circuit::Step.call([ctx, flow_options], **circuit_options) interface
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
      end
    end # Circuit

    # TODO: remove when we drop compatibility.
    module TaskBuilder
      # @deprecated Use {Trailblazer::Activity::Circuit::TaskAdapter.for_step()} instead.
      def self.Binary(user_proc)
        Activity::Circuit::TaskAdapter.for_step(user_proc, option: true)
      end

      class << self
        extend Gem::Deprecate
        deprecate :Binary, "Trailblazer::Activity::Circuit::TaskAdapter.for_step()", 2023, 12
      end
    end
  end # Activity
end
