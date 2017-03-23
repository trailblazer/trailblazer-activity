module Trailblazer
  class Circuit
    #   direction, result = circuit.( circuit[:Start], options, runner: Circuit::Trace.new, stack: [] )
    class Trace
      def call(activity, direction, args, circuit:, stack:, **flow_options)
        activity_name, is_nested = circuit.instance_variable_get(:@name)[activity]
        activity_name ||= activity

        Run.(activity, direction, args, stack: is_nested ? [] : stack, **flow_options).tap do |direction, outgoing_options, **flow_options|
          stack << [activity_name, activity, direction, outgoing_options.dup, is_nested ? flow_options[:stack] : nil ]
        end
      end
    end
  end
end
