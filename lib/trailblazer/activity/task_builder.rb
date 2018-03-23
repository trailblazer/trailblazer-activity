module Trailblazer
  module Activity::TaskBuilder
    # every step is wrapped by this proc/decider. this is executed in the circuit as the actual task.
    # Step calls step.(options, **options, flow_options)
    # Output signal binary: true=>Right, false=>Left.
    # Passes through all subclasses of Direction.~~~~~~~~~~~~~~~~~
    module Binary
      def self.call(user_proc)
        Task.new( Trailblazer::Option::KW( user_proc ), user_proc )
      end

      # Translates the return value of the user step into a valid signal.
      # Note that it passes through subclasses of {Signal}.
      def self.binary_signal_for(result, on_true, on_false)
        result.is_a?(Class) && result < Activity::Signal ? result : (result ? on_true : on_false)
      end
    end

    class Task
      def initialize(task, user_proc)
        @task      = task
        @user_proc = user_proc

        freeze
      end

      def call( (options, *args), **circuit_options )
        # Execute the user step with TRB's kw args.
        result = @task.( options, **circuit_options ) # circuit_options contains :exec_context.

        # Return an appropriate signal which direction to go next.
        signal = Binary.binary_signal_for( result, Activity::Right, Activity::Left )

        return signal, [ options, *args ]
      end

      def inspect
        %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=#{@user_proc}>}
      end
      alias_method :to_s, :inspect
    end
  end
end
