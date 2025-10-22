module Trailblazer
  class Activity
    # Running a Circuit instance will run all tasks sequentially depending on the former's result.
    # Each task is called and retrieves the former task's return values.
    #
    # @param map     [Hash] Defines the wiring.
    # @param termini [Array] Tasks that stop execution of the circuit.
    #
    # @see Activity
    # @api semi-private
    class Circuit
      def initialize(map, termini, start_task:, name: nil)
        @map         = map
        @termini     = termini
        @name        = name
        @start_task  = start_task
      end

      # Invokes the passed task with the circuit interface, nothing more.
      class Runner
        def self.call(task, ctx, flow_options, circuit_options)
          task.(ctx, flow_options, circuit_options)
        end
      end

      # Runs the circuit until we hit a terminus.
      #
      # This method throws exceptions when the returned value of a task doesn't match
      # any wiring.
      #
      # @param task An event or task of this circuit from where to start
      # @param ctx application/user specific data structure
      # @param flow_options Library-specific data, e.g. for tracing.
      # @param circuit_options flow control data for the circuit and nested circuits
      # @return [last_signal, ctx, flow_options]
      #
      # NOTE: returned circuit_options are discarded when calling the runner.
      def call(ctx, flow_options, circuit_options)
        run(ctx, flow_options, **circuit_options)
      end

      # @private
      def run(ctx, flow_options, start_task: @start_task, runner: Runner, **circuit_options)
        task = start_task

        loop do
          last_signal, ctx, flow_options = runner.( # we silently discard returned {circuit_options} if there were any.
            task,
            ctx,
            flow_options,
            circuit_options.merge(
              runner: runner,
            )
          )

          # Stop execution of the circuit when we hit a terminus.
          return last_signal, ctx, flow_options if @termini.include?(task)

          if next_task = next_for(task, last_signal)
            task = next_task
          else
            raise IllegalSignalError.new(
              task,
              **circuit_options,
              signal: last_signal,
              outputs: @map[task],
            )
          end
        end
      end

      # Returns the circuit's components.
      def to_h
        {
          map: @map,
          termini: @termini,
          start_task: @start_task
        }
      end

      private

      def next_for(last_task, signal)
        outputs = @map[last_task]
        outputs[signal]
      end

      # Common reasons to raise IllegalSignalError are when returning signals from
      #   * macros which are not registered
      #   * subprocesses where parent process have not registered that signal
      #   * ciruit interface steps, for example: `step task: method(:validate)`
      class IllegalSignalError < RuntimeError
        attr_reader :task, :signal

        def initialize(task, signal:, outputs:, exec_context:, **)
          @task = task
          @signal = signal

          message = "#{exec_context.class}:\n" \
            "\e[31mUnrecognized signal `#{signal.inspect}` returned from #{task.inspect}. Registered signals are:\e[0m\n" \
            "\e[32m#{outputs.keys.map(&:inspect).join("\n")}\e[0m"

          super(message)
        end
      end
    end
  end
end
