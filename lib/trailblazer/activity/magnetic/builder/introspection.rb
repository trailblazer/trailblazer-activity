module Trailblazer
  module Activity::Magnetic
    module Builder::Introspection
      def self.seq(builder)
        adds = builder.instance_variable_get(:@adds)
        tripletts = Builder::Finalizer.adds_to_tripletts(adds)

        Seq(tripletts)
      end

      def self.cct(builder)
        adds = builder.instance_variable_get(:@adds)
        process, _ = Builder::Finalizer.(adds)

        Cct(process)
      end

      private

        def self.Seq(sequence)
    content =
      sequence.collect do |(magnetic_to, task, plus_poles)|
        pluses = plus_poles.collect { |plus_pole| Seq.PlusPole(plus_pole) }

%{#{magnetic_to.inspect} ==> #{Seq.Task(task)}
#{pluses.empty? ? " []" : pluses.join("\n")}}
      end.join("\n")

    "\n#{content}\n".gsub(/\d\d+/, "")
  end

  module Seq
    def self.PlusPole(plus_pole)
      signal = plus_pole.signal.to_s.sub("Trailblazer::Circuit::", "")
      semantic = plus_pole.send(:output).semantic
      " (#{semantic})/#{signal} ==> #{plus_pole.color.inspect}"
    end

    def self.Task(task)
      return task.inspect unless task.kind_of?(Trailblazer::Circuit::End)

      class_name = strip(task.class)
      name     = task.instance_variable_get(:@name)
      semantic = task.instance_variable_get(:@options)[:semantic]
      "#<#{class_name}:#{name}/#{semantic.inspect}>"
    end

    def self.strip(string)
      string.to_s.sub("Trailblazer::Circuit::", "")
    end
  end
  def self.Cct(process)
    hash = process.instance_variable_get(:@circuit).to_fields[0]

    content =
      hash.collect do |task, connections|
        conns = connections.collect do |signal, target|
          " {#{signal}} => #{Seq.Task(target)}"
        end

        [ Seq.Task(task), conns.join("\n") ]
      end

      content = content.join("\n")

      "\n#{content}".gsub(/\d\d+/, "")
  end
    end
  end
end
