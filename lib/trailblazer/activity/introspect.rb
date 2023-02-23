module Trailblazer
  class Activity
    # The Introspect API provides inflections for `Activity` instances.
    #
    # It abstracts internals about circuits and provides a convenient API to third-parties
    # such as tracing, rendering an activity, or finding particular tasks.
    module Introspect
      # Public entry point for {Activity} instance introspection.
      def self.Nodes(activity, id: nil, task: nil)
        schema = activity.to_h
        nodes  = schema[:nodes]

        return Nodes.find_by_id(nodes, id) if id
        return nodes.fetch(task)           if task
        nodes
      end

      module Nodes
        # @private
        # @return Attributes data structure
        def self.find_by_id(nodes, id)
          tuple = nodes.find { |task, attrs| attrs.id == id } or return
          tuple[1]
        end
      end

      # @private
      def self.find_path(activity, segments)
        raise ArgumentError.new(%{[Trailblazer] Please pass #{activity}.to_h[:activity] into #find_path.}) unless activity.kind_of?(Trailblazer::Activity)

        attributes           = Schema::Nodes::Attributes.new(nil, nil, activity) # FIXME: use attributes from container_activity_for !!!!!!!!!!!!!!!!!
        last_graph, last_activity = nil, TaskWrap.container_activity_for(activity) # needed for empty/root path

        segments.each do |segment|
          nodes      = Introspect.Nodes(activity)
          attributes = Introspect::Nodes.find_by_id(nodes, segment) or return

          last_activity = activity
          last_graph    = nodes

          activity      = attributes.task
        end

        return attributes, last_activity, last_graph
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

      # TODO: remove with 0.1.0.
      def self.Graph(*args)
        Deprecate.warn caller_locations[0], %{`Trailblazer::Activity::Introspect::Graph` is deprecated. Please use `Trailblazer::Developer::Introspect.Graph`}

        Trailblazer::Developer::Introspect::Graph.new(*args)
      end
    end # Introspect
  end
end
