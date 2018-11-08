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

      # TODO: remove Finalizer namespace from NodeConfiguration
      # TODO: order of step/fail/pass in Node would be cool to have


      # @private This API is still under construction.
      class Graph
        def initialize(activity)
          @activity = activity
          @process  = activity.to_h[:process] or raise
          @circuit  = @process.circuit
          @map      = @circuit.to_h[:map]
          @configs  = @process.nodes
        end

        def find(id=nil, &block)
          return find_by_id(id) unless block_given?
          find_with_block(&block)
        end

        def collect(strategy: :circuit, &block)
          @map.keys.collect { |task| yield find_with_block { |node| node.task==task } }
        end

        private

        def find_by_id(id)
          node = @configs.find { |node| node.id == id } or return
          node_for(node)
        end

        def find_with_block(&block)
          existing = @configs.find { |node| yield Node(node.task, node.id, node.outputs) } or return

          node_for(existing)
        end

        def node_for(config)
          Node(config.task, config.id, config.outputs, outgoings_for(config))
        end

        def Node(*args)
          Node.new(*args).freeze
        end

        Node     = Struct.new(:task, :id, :outputs, :outgoings)
        Outgoing = Struct.new(:output, :task)

        def outgoings_for(node)
          outputs     = node.outputs
          connections = @map[node.task]

          connections.collect do |signal, target|
            output = outputs.find { |out| out.signal == signal }
            Outgoing.new(output, target)
          end
        end
      end


        # FIXME: clean up that shit below.
      def self.inspect_task_builder(task)
        proc = task.instance_variable_get(:@user_proc)
        match = proc.inspect.match(/(\w+)>$/)

        %{#<TaskBuilder{.#{match[1]}}>}
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
