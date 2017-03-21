  require "trailblazer/circuit/version"

# Start, Suspend, Resume, End can return something other than the next symbol?
# Nested could replace options with local options


module Trailblazer
  # Circuit executes ties, finds next step and stops when reaching a Stop signal (or derived from).
  #
  #   circuit.()
  #
  # Cicuit doesn't know anything about contexts, options, etc. tasks: what steps follows? call it!
	class Circuit
    def initialize(map, stop_events, name)
      @name        = name
      @map         = map
      @stop_events = stop_events
    end

        # the idea is to always have a breakpoint state that has only one outgoing edge. we then start from
    # that vertix. it's up to the caller to test if the "persisted" state == requested state.
    # activity: where to start
    def call(activity, *args) # DISCUSS: should start activity be @activity and we omit it here?
      # TODO: *args
      direction = nil

      loop do
        puts "[#{@name}]. #{activity}"
        direction, *args  = activity.(direction, *args)

        # last task in a process is always either its Stop or its Suspend.
        return [ direction, *args ] if @stop_events.include?(activity)

        activity = next_for(activity, direction) do |next_activity, in_map|
          puts "[#{@name}]...`#{activity}`[#{direction}] => #{next_activity}"

          raise IllegalInputError.new("#{@name} #{activity}") unless in_map
          # last activity didn't emit knowns signal, it's not connected.
          raise IllegalOutputSignalError.new("from #{@name};;#{activity}"+ direction.inspect) unless next_activity
        end
      end
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




    class End
      def initialize(name, options={})
        @name    = name
        @options = options
      end

      # def to_id
      #   "#{self.class}.#{@name}"
      # end

      def to_s
        %{#<End: #{@name} #{@options.inspect}>}
      end

      def inspect
        to_s
      end

      def call(direction, *args)
        self # TODO: not considered, yet.
        [ self, *args ]
      end
    end

    class Start < End
      def call(direction, *args)
        [Right, *args]
      end

      def to_s
        %{#<Start: #{@name} #{@options.inspect}>}
      end
    end

    # # run a nested process.
    def self.Nested(activity, start_with=activity[:Start])
      # TODO: currently, we only support only 1 start event. you can use multiple in BPMN.
      # "The BPMN standard allows for multiple start and end events to be used at the same process level. "
      ->(start_at, options, *args) {
         # puts "@@@@@ #{options.inspect}"
        activity.(start_with, options, *args)
      }
    end

		class Right
      def self.to_id
        self
      end
    end

    class Left < Right
    end

    def self.Activity(*args)
      Activity.new(*args)
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

    # This is a code structure to encapsulate the circuit execution behavior and the
    # start, intermediate and end events, within a "physical" business process.
    #
    #   activity[:Start]
    #   activity.()
    Activity = Struct.new(:circuit, :events) do
      def [](*args)
        events[*args]
      end

      def call(*args, &block)
        circuit.(*args, &block)
      end

      private :circuit
    end

    # DSL
    #  Conveniently build an Activity with Circuit instance and
    # all its signals/events.
    def self.Activity(name=:default, events={}, end_events=nil, implementation=false, &block)
      # default events:
      start   = events[:start] || { default: Start.new(:default) }
      _end    = events[:end]   || { default: End.new(:default) }

      events = { start: start }.merge(events)
      events = { end:   _end  }.merge(events)

      end_events ||= _end.values

      evts = Circuit::Events(events)
      circuit = Circuit(name, evts, end_events, &block)

      # DISCUSS
      circuit = implementation.(circuit) if implementation

      Activity.new(circuit, evts)
    end

    def self.Circuit(name=:default, events, end_events)
      Circuit.new(yield(events), end_events, name)
    end


    # def self.Implementation(context, circuit, *)
    #   ->(*args) { circuit.(*args, context) }
    # end
    # TODO: Implementation and MyTask go together.

    # NOT lowest level. if you need that, use your own proc.
    # TODO: how do we track what goes into the callable?
    #                 adjust what goes into it (e.g. without direction or with kw args)?
    #                 pre contract -> step -> post contract (are these all just steps, in "mini nested pipe"?)
    #
    #
    # aka "Atom".
    def self.Task(instance: :context, method: :call)
      # * ingoing contract (could be implemented as a nested pipe with 3 steps. that would allow us
      #   to compile it to native ruby method calls later)
      # * ingoing args
      ->(direction, args, opts) {
        instance = opts[:context] if instance==:context # TODO; implement different :context (e.g. :my_context).




        step_args = [args] # TODO: overridable.

        res = instance.send(method, *step_args) # what goes in? kws?
      # * interpret result (e.g. true=>Right)
      # * outgoing contract
      # * outgoing args

        [ *res, opts ]





      }
    end
  end
end
