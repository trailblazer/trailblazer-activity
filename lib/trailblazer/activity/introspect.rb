module Trailblazer
  class Activity < Module
    # The Introspect API abstracts internals about circuits and provides a convenient API
    # to third-parties such as tracing, rendering activities, etc.
    module Introspect
      def self.Graph(*args)
        Graph.new(*args)
      end

      # TODO: remove Finalizer namespace from NodeConfiguration
      # TODO: order of step/fail/pass in Node would be cool to have
      # TODO: #outputs


      # @private This API is still under construction.
      class Graph

        def initialize(activity)
          @activity = activity
          @schema   = activity.to_h[:schema] or raise
          @circuit  = @schema.circuit
          @map      = @circuit.to_h[:map]
          @configs  = @schema.nodes
        end

        def find(id=nil, &block)
          return find_by_id(id) unless block_given?
          find_with_block(&block)
        end

        def collect(strategy: :circuit, &block)
          @map.keys.collect { |task| yield find_with_block { |node| node.task==task } }
        end

        def stop_events
          @circuit.to_h[:end_events]
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
    end #Introspect
  end
end
