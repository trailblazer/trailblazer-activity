  module Trailblazer
    class Activity
      # signal:   actual signal emitted by the task
      # color:    the mapping, where this signal will travel to. This can be e.g. Left=>:success. The polarization when building the graph.
      #             "i am traveling towards :success because ::step said so!"
      # semantic: the original "semantic" or role of the signal, such as :success. This usually comes from the activity hosting this output.
      Output = Struct.new(:signal, :semantic)

      def self.Output(signal, color)
        Output.new(signal, color).freeze
      end

      def self.End(name, semantic=name)
        Circuit::End.new(name, semantic: semantic)
      end
    end
  end
