  module Trailblazer
    class Activity < Module     # End event is just another callable task.

      # Any instance of subclass of End will halt the circuit's execution when hit.

      # An End event is a simple structure typically found as the last task invoked
      # in an activity. The special behavior is that it
      # a) maintains a semantic that is used to further connect that very event
      # b) its `End#call` method returns the end instance itself as the signal.
      End = Struct.new(:semantic) do
        def call(*args)
          return self, *args
        end
      end

      class Start < End
        def call(*args)
          return Activity::Right, *args
        end
      end

      # Builds an Activity::End instance.
      def self.End(semantic)
        Activity::End.new(semantic)
      end

      class Signal;         end
      class Right < Signal; end
      class Left  < Signal; end

      # signal:   actual signal emitted by the task
      # color:    the mapping, where this signal will travel to. This can be e.g. Left=>:success. The polarization when building the graph.
      #             "i am traveling towards :success because ::step said so!"
      # semantic: the original "semantic" or role of the signal, such as :success. This usually comes from the activity hosting this output.
      Output = Struct.new(:signal, :semantic)

      def self.Output(signal, color)
        Output.new(signal, color).freeze
      end
    end
  end
