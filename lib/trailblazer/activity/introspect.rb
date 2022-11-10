module Trailblazer
  class Activity
    # The Introspect API provides inflections for `Activity` instances.
    #
    # It abstracts internals about circuits and provides a convenient API to third-parties
    # such as tracing, rendering an activity, or finding particular tasks.
    module Introspect
      # A TaskMap is a way to introspect an {Activity}. It allows finding a {TaskAttributes}
      # instance by its ID given at compile-time, or its task.
      #
      # It is much simpler and faster than the Graph interface that might get (re)moved.
      def self.TaskMap(activity)
        schema = activity.to_h
        nodes  = schema[:nodes]

        task_map_tuples =
          nodes.collect do |node_attributes|
            [
              task = node_attributes[:task],
              TaskMap::TaskAttributes(id: node_attributes[:id], task: task)
            ]
          end

        TaskMap[task_map_tuples].freeze
      end

      class TaskMap < Hash
        TaskAttributes = Struct.new(:id, :task) # TODO: extend at some point.

        def self.TaskAttributes(id:, task:)
          TaskMap::TaskAttributes.new(id, task).freeze
        end
      end

      # TODO: order of step/fail/pass in Node would be cool to have

      # TODO: Remove Graph. This is only useful to render the full
      # circuit, which is a very specific task that could sit in `developer`,
      # instead.
      # Some thoughts here:
      # * where do we need Schema.outputs? and where task.outputs?
      #
      #
      # @private This API is still under construction.
      class Graph
        def initialize(activity)
          @schema   = activity.to_h or raise
          @circuit  = @schema[:circuit]
          @map      = @circuit.to_h[:map]
          @configs  = @schema[:nodes]
        end

        def find(id = nil, &block)
          return find_by_id(id) unless block_given?

          find_with_block(&block)
        end

        # TODO: convert to {#to_a}.
        def collect(strategy: :circuit)
          @map.keys.each_with_index.collect { |task, i| yield find_with_block { |node| node.task == task }, i }
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

        # Build a {Graph::Node} with outputs etc.
        def node_for(node_attributes)
          Node(
            node_attributes.task,
            node_attributes.id,
            node_attributes.outputs, # [#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>]
            outgoings_for(node_attributes),
            node_attributes.data,
          )
        end

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

      def self.Graph(*args)
        Graph.new(*args)
      end

      # @private
      def self.find_path(activity, segments)
        raise ArgumentError.new(%{[Trailblazer] Please pass #{activity}.to_h[:activity] into #find_path.}) unless activity.kind_of?(Trailblazer::Activity)

        task_attributes           = TaskMap::TaskAttributes(id: nil, task: activity)
        last_graph, last_activity = nil, TaskWrap.container_activity_for(activity) # needed for empty/root path

        segments.each do |segment|
          task_map              = Introspect.TaskMap(activity)
          task, task_attributes = (task_map.find { |task, attributes| attributes[:id] == segment } or return) # DISCUSS: should we abstract these internals of {TaskMap} in {find_by_id}?

          last_activity = activity
          last_graph    = task_map

          activity      = task
        end

        return task_attributes, last_activity, last_graph
      end

      def self.render_task(proc)
        if proc.is_a?(Method)

          receiver = proc.receiver
          receiver = receiver.is_a?(Class) ? (receiver.name || "#<Class:0x>") : (receiver.name || "#<Module:0x>") #"#<Class:0x>"

          return "#<Method: #{receiver}.#{proc.name}>"
        elsif proc.is_a?(Symbol)
          return proc.to_s
        end

        proc.inspect
      end
    end # Introspect
  end
end
