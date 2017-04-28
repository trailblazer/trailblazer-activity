require "trailblazer/circuit/version"

module Trailblazer
  # Running a Circuit instance will run all tasks sequentially depending on the former's result.
  # Each task is called and retrieves the former task's return value.
  #
  #   result = circuit.(start_at, *args)
  class Circuit
    def initialize(map, stop_events, name)
      @name        = name
      @map         = map
      @stop_events = stop_events
    end

    Run = ->(activity, direction, *args) { activity.(direction, *args) }

    # Runs the circuit. Stops when hitting a End event or subclass thereof.
    # This method throws exceptions when the return value of a task doesn't match
    # any wiring.
    # @param activity A task from the circuit where to start
    # @param args An array of options passed to the first task.
    def call(activity, args, runner: Run, **o)
      # TODO: args
      direction = nil

      loop do
        direction, args  = runner.(activity, direction, args, runner: runner, debug: @name, **o)

        # Stop execution of the circuit when we hit a stop event (< End). This could be an activity's End of Suspend.
        return [ direction, args, **o ] if @stop_events.include?(activity)

        activity = next_for(activity, direction) do |next_activity, in_map|
          raise IllegalInputError.new("#{@name} #{activity}") unless in_map
          raise IllegalOutputSignalError.new("from #{@name};;#{activity}"+ direction.inspect) unless next_activity
        end
      end
    end

    # Returns the circuit's components.
    def to_fields
      [ @map, @stop_events, @name]
    end

  private
    def next_for(last_activity, emitted_direction)
      # p @map
      in_map        = false
      cfg           = @map.keys.find { |t| t == last_activity } and in_map = true
      cfg = @map[cfg] if cfg
      cfg         ||= {}
      next_activity = cfg[emitted_direction]
      yield next_activity, in_map

      next_activity
    end

    class IllegalInputError < RuntimeError
    end

    class IllegalOutputSignalError < RuntimeError
    end

    def Right
      Right
    end

    def Left
      Left
    end

    # A end event is just another callable task, but will cause the circuit's execution to halt when hit.
    class End
      def initialize(name, options={})
        @name    = name
        @options = options
      end

      def call(direction, *args)
        [ self, *args ]
      end
    end

    class Start < End
      def call(direction, *args)
        [ Right, *args ]
      end
    end

    def self.End(name, options={})
      End.new(name, options)
    end

    def self.Start(name, options={})
      Start.new(name, options)
    end

    # # run a nested process.
    def self.Nested(activity, start_with=activity[:Start])
      # TODO: currently, we only support only 1 start event. you can use multiple in BPMN.
      # "The BPMN standard allows for multiple start and end events to be used at the same process level. "
      ->(start_at, options, *args) {
        activity.(start_with, options, *args)
      }
    end

    class Direction;         end
		class Right < Direction; end
    class Left  < Direction; end
  end
end

require "trailblazer/circuit/activity"
require "trailblazer/circuit/task"
require "trailblazer/circuit/alter"
require "trailblazer/circuit/trace"
