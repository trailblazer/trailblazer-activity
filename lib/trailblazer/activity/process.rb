module Trailblazer
  class Activity::Process
    # The executable run-time instance for an Activity.
    def initialize(circuit_hash, end_events)
      @default_start_event = circuit_hash.keys.first
      @circuit             = Circuit.new(circuit_hash, end_events)
    end

    def call(args, task: @default_start_event, **circuit_options)
      @circuit.(
        args,
        circuit_options.merge( task: task ) , # this passes :runner to the {Circuit}.
      )
    end

    def decompose
      return @circuit, @default_start_event
    end
  end
end
