module Trailblazer
  class Activity < Module
    # Compile-time.
    # Introspection is not used at run-time except for rendering diagrams, tracing, and the like.
    module Introspect
      def self.Graph(*args)
        Graph.new(*args)
      end

      # Graph::Annotation

      # we need
      # original task
      # id
      #
      #   to place them easier in the grid:
      # output semantic/signal
      # magnetic_to

      # @private This API is still under construction.
      class Graph
        def initialize(activity)
          @activity = activity
          @process  = activity.to_h[:process] or raise
          @circuit  = @process.circuit
          @configs  = @process.nodes
        end

        def find(id=nil, &block)
          return find_by_id(id) unless block_given?
          find_with_block(&block)
        end

        private

        def find_by_id(id)
          node = @configs.find { |node| node.id == id } or return

          Node(node.task, node.id, node.outputs)
        end

        def find_with_block(&block)
          existing = @configs.find { |node| yield Node(node.task, node.id, node.outputs) } or return

          Node(existing.task, existing.id, existing.outputs)
        end

        def Node(*args)
          Node.new(*args).freeze
        end

        Node = Struct.new(:task, :id, :outputs)
      end


      # FIXME: remove this
      # @private This will be removed shortly.
      def self.collect(activity, options={}, &block)
        circuit      = activity.to_h[:circuit]
        circuit_hash = circuit.to_h[:map]

        locals = circuit_hash.collect do |task, connections|
          [
            yield(task, connections),
            *options[:recursive] && task.is_a?(Activity::Interface) ? collect(task, options, &block) : []
          ]
        end.flatten(1)
      end

      def self.inspect_task_builder(task)
        proc = task.instance_variable_get(:@user_proc)
        match = proc.inspect.match(/(\w+)>$/)

        %{#<TaskBuilder{.#{match[1]}}>}
      end

        # FIXME: clean up that shit below.

# render
      def self.Cct(circuit, **options)
        circuit_hash( circuit.to_h[:map], **options )
      end

      def self.circuit_hash(circuit_hash, show_ids:false, **options)
        content = circuit_hash.collect do |task, connections|
          conns = connections.collect do |signal, target|
            " {#{signal}} => #{inspect_with_matcher(target, **options)}"
          end

          [ inspect_with_matcher(task, **options), conns.join("\n") ]
        end

        content = content.join("\n")

        return "\n#{content}" if show_ids
        return "\n#{content}".gsub(/0x\w+/, "0x").gsub(/0.\d+/, "0.")
      end

      def self.Ends(activity)
        end_events = activity.to_h[:end_events]
        ends = end_events.collect { |evt| inspect_end(evt) }.join(",")
        "[#{ends}]".gsub(/\d\d+/, "")
      end

      def self.Outputs(outputs)
        outputs.collect { |semantic, output| "#{semantic}=> (#{output.signal}, #{output.semantic})" }.
          join("\n").gsub(/0x\w+/, "").gsub(/\d\d+/, "")
      end

      # If Ruby had pattern matching, this function wasn't necessary.
      def self.inspect_with_matcher(task, inspect_task: method(:inspect_task), inspect_end: method(:inspect_end))
        return inspect_task.(task) unless task.kind_of?(Trailblazer::Activity::End)
        inspect_end.(task)
      end

      def self.inspect_task(task)
        task.inspect
      end

      def self.inspect_end(task)
        class_name = strip(task.class)
        options    = task.to_h

        "#<#{class_name}/#{options[:semantic].inspect}>"
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
        circuit, _ = Builder::Finalizer.(adds)

        Cct(circuit)
      end

      private

      def self.Seq(sequence)
        content =
          sequence.collect do |(magnetic_to, task, plus_poles)|
            pluses = plus_poles.collect { |plus_pole| PlusPole(plus_pole) }

%{#{magnetic_to.inspect} ==> #{Activity::Introspect.inspect_with_matcher(task)}
#{pluses.empty? ? " []" : pluses.join("\n")}}
          end.join("\n")

    "\n#{content}\n".gsub(/\d\d+/, "").gsub(/0x\w+/, "0x")
      end

      def self.PlusPole(plus_pole)
        signal = plus_pole.signal.to_s.sub("Trailblazer::Activity::", "")
        semantic = plus_pole.send(:output).semantic
        " (#{semantic})/#{signal} ==> #{plus_pole.color.inspect}"
      end
    end
  end
end
