module Trailblazer
  class Activity
     # A {Subprocess} is an instance of an abstract {Activity} that can be `call`ed.
     # It is the runtime instance that runs from a specific start event.
    def self.Subprocess(*args, &block)
      Subprocess.new(*args, &block)
    end

    # Subprocess allows to have tasks with a different call interface and start event.
    # @param activity any object with an {Activity interface}
    class Subprocess
      def initialize(activity, call: :call, **options, &block)
        @activity = activity
        @options = options
        @call     = call
        @block    = block
      end

      def call(args)
        @activity.public_send(@call, args, @options)
      end

      # @private
      attr_reader :activity # we actually only need this for introspection.
    end
  end
end

# circuit.( args, runner: Runner, start_at: raise, **circuit_flow_options )

# subprocess.( options, flow_options, *args, start_event:<Event>, last_signal: signal )
