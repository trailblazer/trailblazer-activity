module Trailblazer
  class Activity
    # Introspection is not used at run-time except for rendering diagrams, tracing, and the like.
    module Introspect
      # {:argumenter} API
      def self.arguments_for_call(activity, (options, flow_options), **circuit_options)
        circuit_options = circuit_options.merge( introspect: activity.debug )

        return activity, [ options, flow_options ], circuit_options
      end

      # {Extension} API
      def self.add_introspection(activity, task, local_options, *returned_options)
        activity.debug[task] = { id: local_options[:id] || task }.freeze
      end


        # FIXME: clean up that shit below.

      def self.collect(activity, options={}, &block)
        process, _      = activity.decompose
        circuit, _      = process.decompose
        circuit_hash, _ = circuit.decompose

        locals = circuit_hash.collect do |task, connections|
          [
            yield(task, connections),
            *options[:recursive] && task.is_a?(Activity::Interface) ? collect(task, options, &block) : []
          ]
        end.flatten(1)
      end

      # @private
      # DISCUSS: #each instead?
      # FIXME: move to Introspection
      def self.find(&block)
        @process.instance_variable_get(:@circuit).instance_variable_get(:@map).find(&block)
      end


# render
      def self.Cct(process, **options)
        circuit_hash( process.instance_variable_get(:@circuit).decompose[0], **options )
      end

      def self.circuit_hash(circuit_hash, show_ids:false)
        content =
          circuit_hash.collect do |task, connections|
            conns = connections.collect do |signal, target|
              " {#{signal}} => #{Task(target)}"
            end

            [ Task(task), conns.join("\n") ]
          end

          content = content.join("\n")

          return "\n#{content}" if show_ids
          return "\n#{content}".gsub(/\d\d+/, "")
      end

      def self.Ends(process)
        end_events = process.instance_variable_get(:@circuit).decompose[1]
        ends = end_events.collect { |evt| Task(evt) }.join(",")
        "[#{ends}]".gsub(/\d\d+/, "")
      end


      def self.Outputs(outputs)
        outputs.collect { |semantic, output| "#{semantic}=> (#{output.signal}, #{output.semantic})" }.
          join("\n").gsub(/0x\w+/, "").gsub(/\d\d+/, "")
      end

      def self.Task(task)
        return task.inspect unless task.kind_of?(Trailblazer::Activity::End)

        class_name = strip(task.class)
        name     = task.instance_variable_get(:@name)
        semantic = task.instance_variable_get(:@options)[:semantic]
        "#<#{class_name}:#{name}/#{semantic.inspect}>"
      end

      def self.strip(string)
        string.to_s.sub("Trailblazer::Activity::", "")
      end
    end #Introspect
  end

  module Activity::Magnetic
    module Introspect
      def self.seq(activity)
        adds = activity.instance_variable_get(:@adds)
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
            pluses = plus_poles.collect { |plus_pole| PlusPole(plus_pole) }

%{#{magnetic_to.inspect} ==> #{Activity::Introspect.Task(task)}
#{pluses.empty? ? " []" : pluses.join("\n")}}
          end.join("\n")

    "\n#{content}\n".gsub(/\d\d+/, "")
      end

      def self.PlusPole(plus_pole)
        signal = plus_pole.signal.to_s.sub("Trailblazer::Activity::", "")
        semantic = plus_pole.send(:output).semantic
        " (#{semantic})/#{signal} ==> #{plus_pole.color.inspect}"
      end


    end
  end
end
