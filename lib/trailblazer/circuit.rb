module Trailblazer
  # Running a Circuit instance will run all tasks sequentially depending on the former's result.
  # Each task is called and retrieves the former task's return values.
  #
  # Note: Please use #Activity as a public circuit builder.
  #
  # @param map         [Hash] Defines the wiring.
  # @param stop_events [Array] Tasks that stop execution of the circuit.
  # @param name        [Hash] Names for tracing, debugging and exceptions. `:id` is a reserved key for circuit name.
  #
  #   result = circuit.(start_at, *args)
  #
  # @see Activity
  # @api semi-private
  class Circuit
    def initialize(map, stop_events, name)
      @map         = map
      @stop_events = stop_events
      @name        = name
    end

    # @param args [Array] all arguments to be passed to the task's `call`
    # @param task [callable] task to call
    Run = ->(task, args, **circuit_options) { task.(args, **circuit_options) }

    # Runs the circuit until we hit a stop event.
    #
    # This method throws exceptions when the returned value of a task doesn't match
    # any wiring.
    #
    # @param task An event or task of this circuit from where to start
    # @param options anything you want to pass to the first task
    # @param flow_options Library-specific flow control data
    # @return [last_signal, options, flow_options, *args]
    #
    # DISCUSS: returned circuit_options are ignored when calling the runner.
    def call(args, task: raise, runner: Run, **circuit_options)
      loop do
        last_signal, args, _ignored_circuit_options = runner.(
          task,
          args,
          circuit_options.merge( runner: runner ) # options for runner, to be discarded.
        )

        # Stop execution of the circuit when we hit a stop event (< End). This could be an task's End or Suspend.
        return [ last_signal, args ] if @stop_events.include?(task) # DISCUSS: return circuit_options here?

        task = next_for(task, last_signal) do |next_task, in_map|
          task_name = @name[task] || task # TODO: this must be implemented only once, somewhere.
          raise IllegalInputError.new("#{@name[:id]} #{task_name}") unless in_map
          raise IllegalOutputSignalError.new("from #{@name[:id]}: `#{task_name}`===>[ #{last_signal.inspect} ]") unless next_task
        end
      end
    end

    # Returns the circuit's components.
    def to_fields
      [ @map, @stop_events, @name]
    end

  private
    def next_for(last_task, emitted_signal)
      # p @map
      in_map        = false
      cfg           = @map.keys.find { |t| t == last_task } and in_map = true
      cfg = @map[cfg] if cfg
      cfg         ||= {}
      next_task = cfg[emitted_signal]
      yield next_task, in_map

      next_task
    end

    class IllegalInputError < RuntimeError
    end

    class IllegalOutputSignalError < RuntimeError
    end

    # End event is just another callable task.
    # Any instance of subclass of End will halt the circuit's execution when hit.
    class End
      def initialize(name, options={})
        @name    = name
        @options = options
      end

      def call(*args)
        [ self, *args ]
      end
    end

    class Start < End
      def call(*args)
        [ Right, *args ]
      end
    end

    # Builder for Circuit::End when defining the Activity's circuit.
    def self.End(name, options={})
      End.new(name, options)
    end

    class Signal;         end
		class Right < Signal; end
    class Left  < Signal; end
  end
end
