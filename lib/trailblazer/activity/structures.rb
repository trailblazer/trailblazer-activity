  module Trailblazer
    class Activity
      # End event is just another callable task.
      # Any instance of subclass of End will halt the circuit's execution when hit.
      class End
        def initialize(name, options={})
          @name    = name
          @options = options
        end

        def call(*args)
          [ self, *args ]
        end
      end

      class Start < End
        def call(*args)
          return Activity::Right, *args
        end
      end

      # Builder for Activity::End.
      def self.End(name, semantic=name)
        Activity::End.new(name, semantic: semantic)
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
