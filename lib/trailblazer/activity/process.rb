module Trailblazer
  class Activity::Process
    # The executable run-time instance for an Activity.
    def initialize(circuit_hash, outputs)
      @default_start_event = circuit_hash.keys.first
      @circuit             = Circuit.new(circuit_hash, outputs.keys, {})
    end

    def call(args, start_event: @default_start_event, **circuit_options)
      @circuit.(
        args,
        circuit_options.merge( task: start_event) , # this passes :runner to the {Circuit}.
      )
    end
  end
end
