module Trailblazer
  class Activity
    # Generic run-time structures that are built via the DSL.

    # Any instance of subclass of End will halt the circuit's execution when hit.
    # An End event is a simple structure typically found as the last task invoked
    # in an activity. The special behavior is that it
    # a) maintains a semantic that is used to further connect that very event
    # b) its `End#call` method returns the end instance itself as the signal.
    class End
      def initialize(semantic:, **options)
        @options = options.merge(semantic: semantic)
      end

      def call(ctx, flow_options, circuit_options)
        return ctx, flow_options, self
      end

      def to_h
        @options
      end

      def to_s
        %(#<#{self.class.name} #{@options.collect { |k, v| "#{k}=#{v.inspect}" }.join(" ")}>)
      end

      alias inspect to_s
    end

    # DISCUSS: we actually don't need this here anymore, this is only good for modeling in the DSL.
    class Start < End
      def call(ctx, flow_options, circuit_options)
        return ctx, flow_options, Activity::Right
      end
    end

    class Signal; end

    class Right < Signal; end

    class Left < Signal; end

    # signal:   actual signal emitted by the task
    # color:    the mapping, where this signal will travel to. This can be e.g. Left=>:success. The polarization when building the graph.
    #             "i am traveling towards :success because ::step said so!"
    # semantic: the original "semantic" or role of the signal, such as :success. This usually comes from the activity hosting this output.
    Output = Struct.new(:signal, :semantic)

    # Builds an {Activity::Output} instance.
    def self.Output(signal, semantic)
      Output.new(signal, semantic).freeze
    end

    # Builds an {Activity::End} instance.
    def self.End(semantic)
      End.new(semantic: semantic)
    end
  end
end
