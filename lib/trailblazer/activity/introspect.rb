module Trailblazer
  class Activity
    # The Introspect API provides inflections for `Activity` instances.
    # It abstracts internals about circuits and provides a convenient API to third-parties such as
    # tracing, rendering an activity, or finding particular tasks.
    module Introspect
      # TODO: order of step/fail/pass in Node would be cool to have

      # @private This API is still under construction.
      class Graph
        def initialize(activity)
          @activity = activity
          @schema   = activity.to_h or fail
          @circuit  = @schema[:circuit]
          @map      = @circuit.to_h[:map]
          @configs  = @schema[:nodes]
        end

        def find(id = nil, &block)
          return find_by_id(id) unless block_given?

          find_with_block(&block)
        end

        def collect(strategy: :circuit)
          case strategy
            when :circuit
              @map.keys.each_with_index.collect { |task, i| yield find_with_block { |node| node.task == task }, i }
            else
              fail ArgumentError, "unknown strategy: #{strategy}"
          end
        end

        def stop_events
          @circuit.to_h[:end_events]
        end

        private

        def find_by_id(id)
          node = @configs.find { |_node| _node.id == id } or return
          node_for(node)
        end

        def find_with_block
          existing = @configs.find { |node| yield Node(node.task, node.id, node.outputs, node.data) } or return

          node_for(existing)
        end

        def node_for(node_attributes)
          Node(node_attributes.task, node_attributes.id, node_attributes.outputs, outgoings_for(node_attributes), node_attributes.data)
        end

        # noinspection RubyClassMethodNamingConvention
        def Node(*args)
          Node.new(*args).freeze
        end

        Node     = Struct.new(:task, :id, :outputs, :outgoings, :data)
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

      # noinspection RubyClassMethodNamingConvention
      def self.Graph(*args)
        Graph.new(*args)
      end

      def self.render_task(proc)
        case proc
          when Method
            receiver = proc.receiver
            receiver = receiver.is_a?(Class) ? (receiver.name || "#<Class:0x>") : (receiver.name || "#<Module:0x>") # "#<Class:0x>"
            return "#<Method: #{receiver}.#{proc.name}>"
          when Symbol
            return proc.to_s
        end

        proc.inspect
      end
    end
  end
end
