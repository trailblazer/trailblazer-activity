module Trailblazer
  module Activity::TaskBuilder
    # every step is wrapped by this proc/decider. this is executed in the circuit as the actual task.
    # Step calls step.(options, **options, flow_options)
    # Output signal binary: true=>Right, false=>Left.
    # Passes through all subclasses of Direction.~~~~~~~~~~~~~~~~~
    def self.Binary(user_proc)
      Task.new(Trailblazer::Option(user_proc), user_proc)
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

    # Wraps a {task} (that usually expects the task interface) into a circuit interface
    # that can be used directly in a {Circuit}.
    # We expect {task} to be exposing an {Option()} interface when calling it.
    class Task
      def initialize(task, user_proc)
        @task            = task
        @user_proc       = user_proc
        freeze
      end

      def call((ctx, flow_options), **circuit_options)
        # Execute the user step with TRB's kw args.
        # {@task} is/implements {Trailblazer::Option} interface.
        result = call_option(@task, [ctx, flow_options], **circuit_options)

        # Return an appropriate signal which direction to go next.
        signal = Activity::TaskBuilder.binary_signal_for(result, Activity::Right, Activity::Left)

        return signal, [ctx, flow_options]
      end

      # Invoke the original {user_proc} that is wrapped in an {Option()}.
      private def call_option(task_with_option_interface, (ctx, flow_options), **circuit_options)
        task_with_option_interface.(ctx, keyword_arguments: ctx.to_hash, **circuit_options) # circuit_options contains :exec_context.
      end

      def inspect # TODO: make me private!
        %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=#{Trailblazer::Activity::Introspect.render_task(@user_proc)}>}
      end
      alias_method :to_s, :inspect
    end
  end
end
