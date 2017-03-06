  require "trailblazer/circuit/version"

# Start, Suspend, Resume, End can return something other than the next symbol?
# Nested could replace options with local options


module Trailblazer
  # Circuit executes ties, finds next step.
	class Circuit
		def initialize(name=:default, events={})
      @event= {}
      @event[:start] = events[:start] || { default: Start.new(:default) }
      @event[:end]   = events[:end]   || { default: End.new(:default) }

      @name    = name
      @map     = yield self
		end

    def Right
      Right
    end

    def Left
      Left
    end

    def Start(name=:default)
      @event[:start][name]
    end

    def End(name=:default) #DSL
      @event[:end][name]
    end

		# the idea is to always have a breakpoint state that has only one outgoing edge. we then start from
		# that vertix. it's up to the caller to test if the "persisted" state == requested state.
    # activity: where to start
		def call(activity, options) # DISCUSS: should start activity be @activity and we omit it here?
      # TODO: *args
      direction = nil

      loop do
        puts "[#{@name}]. #{activity}"
        direction, options  = activity.(direction, options)

        # last task in a process is always either its Stop or its Suspend.




        # return [ direction, options ] if activity.instance_of?(@suspend_class)






        # stop execution when STOP.
        return [ direction, options ] if @event[:end].values.include?(activity)

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

    class End
      def initialize(name, options={})
        @name    = name
        @options = options
      end

      def to_id
        "#{self.class}.#{@name}"
      end

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

    class Suspend < End
      def to_s
        %{#<Suspend: #{@name}>}
      end

      def to_resume
        options = @options.dup
        options[:__nested] = options[:__nested].to_resume if options[:__nested]
        options.delete(:resume_class).new(@name, options)
      end

      def to_suspend(data={})
        self.class.new(@name, @options.merge(data))
      end

      def inspect
        # %{#<Suspend: #{@name} #{@options.inspect}>}
        %{#<Suspend: #{@name} #{@options.inspect}>}
      end
    end

    class Resume < End
      def to_s
        %{#<Resume: #{@name}>}
      end

      def inspect
        %{#<Resume: #{@name} #{@options.inspect}>}
      end

      def Resume(options)
        self.class.new(@name, @options.merge(options))
      end

      def to_session
        @options
      end
    end

    # # run a nested process.
    def self.Nested(process, start_with=process.Start)
      # TODO: currently, we only support only 1 start event. you can use multiple in BPMN.
      # "The BPMN standard allows for multiple start and end events to be used at the same process level. "
      ->(start_at, options, *args) {
         # puts "@@@@@ #{options.inspect}"
        process.(start_with, options, *args)
      }
    end

		class Right
      def self.to_id
        self
      end
    end

    class Left < Right
    end

    def self.Task(step, id)
      Task.new(step, id)
    end

    def self.Subprocess(step, id)
      Task(step, id)
    end

    class Task
      def initialize(step, id)
        @step, @to_id = step, id
      end

      def call(direction, *args, &block)
        @step.(*args, &block)
      end

      attr_reader :to_id
    end
	end
end
