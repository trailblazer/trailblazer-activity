module Trailblazer
  class Activity
    # Circuit::TaskAdapter:   Uses Circuit::Step to translate incoming, and returns a circuit-interface
    #                 compatible return set.
    class Circuit
      # Single-entry point to build a step with a circuit interface that is internally
      # calling a user code chunk with a step interface (ctx, **ctx).
      #
      # In TRB 2.1, this used to sit in the Trailblazer::Option gem, but never really made sense
      # as we're building
      def self.Step(user_filter_with_step_interface, option: nil, **options)
raise if option # FIXME: remove once this is sorted.

        options = options.merge(instance_method: true) if user_filter_with_step_interface.is_a?(Symbol)

        Step.build(user_filter_with_step_interface, **options)
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
          # and then return the new ctx here. it's much more convenient letting OP steps mutate the ctx directly, though.

          return ctx, flow_options, result
        end

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
