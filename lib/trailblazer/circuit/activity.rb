module Trailblazer
  class Circuit
    # This is a code structure to encapsulate the circuit execution behavior and the
    # start, intermediate and end events, within a "physical" business process.
    #
    #   activity[:Start]
    #   activity.()
    #   activity.values
    Activity = Struct.new(:circuit, :events) do
      def [](*args)
        events[*args]
      end

      def call(*args, &block)
        circuit.(*args, &block)
      end
    end

    # Conveniently build an Activity with Circuit instance and events.
    def self.Activity(name=:default, events={}, end_events=nil, implementation=false, &block)
      # default events:
      start   = events[:start] || { default: Start.new(:default) }
      _end    = events[:end]   || { default: End.new(:default) }

      events = { start: start }.merge(events)
      events = { end:   _end  }.merge(events)

      end_events ||= _end.values

      evts = Events(events)
      circuit = Circuit(name, evts, end_events, &block)

      # DISCUSS: remove this!
      circuit = implementation.(circuit) if implementation

      Activity.new(circuit, evts)
    end

    def self.Circuit(name=:default, events, end_events)
      Circuit.new(yield(events), end_events, name)
    end

    # DSL
    #   events[:Start]
    #
    # :private:
    def self.Events(events)
      evts = Struct.new(*events.keys) do # [Start, End, Resume]
        def [](event, name=:default)
          cfg = super(event.downcase)
          cfg[name] or raise "[Circuit] Event `#{event}.#{name} unknown."
        end
      end

      evts.new(*events.values)
    end
  end
end
