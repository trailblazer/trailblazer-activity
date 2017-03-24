module Trailblazer
  class Circuit
    #   direction, result = circuit.( circuit[:Start], options, runner: Circuit::Trace.new, stack: [] )
    class Trace
      def call(activity, direction, args, circuit:, stack:, **flow_options)
        activity_name, is_nested = circuit.instance_variable_get(:@name)[activity]
        activity_name ||= activity

        Run.(activity, direction, args, stack: is_nested ? [] : stack, **flow_options).tap do |direction, outgoing_options, **flow_options|
          # TODO: fix the inspect, we need a snapshot, deep-nested.
          stack << [activity_name, activity, direction, outgoing_options, outgoing_options.inspect, is_nested ? flow_options[:stack] : nil ]
        end
      end

      # module_function
      def self.print(stack, level=1)
        stack.each do |i|
          puts "  "*level + i[0].to_s
          if i.last.is_a?(Array)
            # indent = " "*2
            print(i.last, level+1)
          end
        end
      end
    end # Trace
  end
end
