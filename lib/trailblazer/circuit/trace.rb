module Trailblazer
  class Circuit
    #   direction, result = circuit.( circuit[:Start], options, runner: Circuit::Trace.new, stack: [] )

    # Every `activity.call` is considered nested
    class Trace
      def call(activity, direction, args, debug:raise, stack:raise, **flow_options)
        activity_name, _ = debug[activity]
        activity_name ||= activity

        Run.(activity, direction, args, stack:[], **flow_options).tap do |direction, outgoing_options, **flow_options| # TODO: USE KW ARG FOR :stack
          # raise activity_name.inspect if flow_options[:stack].nil? # TODO: remove this.
          # TODO: fix the inspect, we need a snapshot, deep-nested.
          stack << [activity_name, activity, direction, outgoing_options, outgoing_options.inspect, flow_options[:stack].any? ? flow_options[:stack] : nil ]
        end
      end
    end # Trace
  end
end
