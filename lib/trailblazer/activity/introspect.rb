module Trailblazer
  class Activity
    # The Introspect API provides inflections for `Activity` instances.
    #
    # It abstracts internals about circuits and provides a convenient API to third-parties
    # such as tracing, rendering an activity, or finding particular tasks.
    module Introspect
      # Public entry point for {Activity} instance introspection.
      def self.Nodes(activity, task: nil, **options)
        schema = activity.to_h
        nodes  = schema[:nodes]

        return Nodes.find_by_id(nodes, options[:id]) if options.key?(:id)
        return nodes.fetch(task)                     if task
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
        raise ArgumentError.new(%([Trailblazer] Please pass #{activity}.to_h[:activity] into #find_path.)) unless activity.is_a?(Trailblazer::Activity)

        segments = [nil, *segments]

        attributes    = nil
        last_activity = nil
        activity      = TaskWrap.container_activity_for(activity) # needed for empty/root path

        segments.each do |segment|
          attributes    = Introspect.Nodes(activity, id: segment) or return nil
          last_activity = activity
          activity      = attributes.task
        end

        return attributes, last_activity
      end

      def self.render_task(proc)
        if proc.is_a?(Method)

          receiver = proc.receiver
          receiver = receiver.is_a?(Class) ? (receiver.name || "#<Class:0x>") : (receiver.name || "#<Module:0x>") # "#<Class:0x>"

          return "#<Method: #{receiver}.#{proc.name}>"
        elsif proc.is_a?(Symbol)
          return proc.to_s
        end

        proc.inspect
      end
    end # Introspect
  end
end
