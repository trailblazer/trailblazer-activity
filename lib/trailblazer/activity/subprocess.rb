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
      def initialize(activity, call: :call, **activity_options, &block)
        @activity = activity
        @activity_options = activity_options
        @call     = call
        @block    = block
      end

      def call(last_signal, *args)
        return @block.(activity: @activity, start_event: @start_event, args: args) if @block

        # fixme.
        @activity.public_send(@call, *args, @activity_options)
      end

      # @private
      attr_reader :activity # we actually only need this for introspection.
    end
  end
end

# circuit.( args, runner: Runner, start_at: raise, **circuit_flow_options )

# subprocess.( options, flow_options, *args, start_event:<Event>, last_signal: signal )
