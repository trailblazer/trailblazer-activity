require "forwardable"

module Trailblazer
  # Note that Graph is a superset of a real directed graph. For instance, it might contain detached nodes.
  # == Design
  # * This class is designed to maintain a graph while building up a circuit step-wise.
  # * It can be imperformant as this all happens at compile-time.
  module Activity::Graph
    # Task => { name: "Nested{Task}", type: :subprocess, boundary_events: { Circuit::Left => {} }  }

    # Edge keeps references to its peer nodes via the `:source` and `:target` options.
    class Edge
      def initialize(data)
        @data = data.freeze
      end

      def [](key)
        @data[key]
      end

      def to_h
        @data.to_h
      end
    end

    # Node does only save meta data, and has *no* references to edges.
    class Node < Edge
    end

    class Start < Node
      def initialize(data)
        yield self, data if block_given?
        super
      end

      # Builds a node from the provided `:target` arguments and attaches it via `:edge` to `:source`.
      # @param target: Array wrapped, options
      def attach!(target:raise, edge:raise, source:self)
        target = add!(target)

        connect!(target: target, edge: edge, source: source)
      end

      def connect!(target:raise, edge:raise, source:self)
        target = target.kind_of?(Node) ? target : (find_all(target)[0] || raise( "#{target} not found")) # FIXME: only needed for recompile_activity.
        source = source.kind_of?(Node) ? source : (find_all(source)[0] || raise( "#{source} not found"))

        connect_for!(source, edge, target)
      end

      def insert_before!(old_node, node:raise, outgoing:nil, incoming:raise)
        old_node = find_all(old_node)[0] || raise( "#{old_node} not found") unless old_node.kind_of?(Node) # FIXME: do we really need this?
        new_node = add!(node)

        incoming_edges = predecessors(old_node)
        rewired_edges  = incoming_edges.find_all { |(node, edge)| incoming.(edge) }

        # rewire old_task's predecessors to new_task.
        rewired_edges.each { |left_node, edge| reconnect!(left_node, edge, new_node) }

        # connect new_task --> old_task.
        if outgoing
          node, edge = connect_for!(new_node, outgoing, old_node)
        end

        return new_node
      end

      def find_all(id=nil, &block)
        nodes = self[:graph].keys + self[:graph].values.collect(&:values).flatten
        nodes = nodes.uniq

        nodes.find_all(& block || ->(node) { node[:id] == id })
      end

      def predecessors(target_node)
        self[:graph].each_with_object([]) do |(node, connections), ary|
          connections.each { |edge, target| target == target_node && ary << [node, edge] }
        end
      end

      def successors(node)
        ( self[:graph][node] || [] ).collect { |edge, target| [target, edge] }
      end

      def to_h(include_leafs:true)
        hash = ::Hash[
          self[:graph].collect do |node, connections|
            connections = connections.collect { |edge, node| [ edge[:_wrapped], node[:_wrapped] ] }

            [ node[:_wrapped], ::Hash[connections] ]
          end
        ]

        if include_leafs == false
          hash = hash.select { |node, connections| connections.any? }
        end

        hash
      end

      # @private
      def Node(wrapped, id:raise("No ID was provided for #{wrapped}"), **options)
        Node.new( options.merge( id: id, _wrapped: wrapped ) )
      end

    private

      # Single entry point for adding nodes and edges to the graph.
      # @private
      # @return target Node
      # @return edge Edge the edge created connecting source and target.
      def connect_for!(source, edge_args, target)
        edge = Edge(source, edge_args, target)

        self[:graph][source][edge] = target

        return target, edge
      end

      # Removes edge.
      # @private
      def unconnect!(node, edge)
        self[:graph][node].delete(edge)
      end

      # @private
      # Create a Node and add it to the graph, without connecting it.
      def add!(node_args)
        new_node = Node(*node_args)

        raise IllegalNodeError.new("The ID `#{new_node[:id]}` has been added before.") if find_all( new_node[:id] ).any?

        self[:graph][new_node] = {}
        new_node
      end

      # @private
      def reconnect!(left_node, edge, new_node)
        unconnect!(left_node, edge) # dump the old edge.
        connect_for!(left_node, [ edge[:_wrapped], edge.to_h ], new_node)
      end

      # @private
      def Edge(source, (wrapped, options), target) # FIXME: test required id. test source and target
        id   = "#{source[:id]}-#{wrapped}-#{target[:id]}"
        edge = Edge.new(options.merge( _wrapped: wrapped, id: id, source: source, target: target ))
      end
    end

    def self.Start(wrapped, graph:{}, **data, &block)
      block ||= ->(node, data) { data[:graph][node] = {} }
      Start.new( { _wrapped: wrapped, graph: graph }.merge(data), &block )
    end

    class IllegalNodeError < RuntimeError
    end
  end # Graph
end
