module Trailblazer
  # Schema helps you managing the construction of an {Activity}.
  # It is used in the Operation and Activity DSL, and also for the TaskWrap.
  # A Schema always produces an Activity.
  class Activity::Schema
    Output = Struct.new(:signal, :role)
    Line   = Struct.new(:source, :output)

    class OpenLines
      def initialize
        @arr = []
      end

      def pop(signal)
        lines = @arr.find_all { |line| line.output.role == signal }
        @arr -= lines
        lines
      end

      def <<((node, output))
        @arr << Line.new(node, output)
      end
    end

    def self.bla(tasks, start_events: [Circuit::Start.new(:default)])
          added_tasks      = {}
          open_outgoing_lines = OpenLines.new
          open_incoming_lines = OpenLines.new

      circuit_hash = {}

      start_events.each do |evt|
        circuit_hash[evt] = {}
        open_outgoing_lines << [ evt, Output.new(Circuit::Right, :success) ]
      end

      tasks.each do |(magnetic_to, node, outputs)|
        puts "~~~~~~~~~ drawing #{node} which wants #{magnetic_to}"

        magnetic_to.each do |edge_color|
          incoming_lines = open_outgoing_lines.pop(edge_color)

          if incoming_lines.empty?
            puts("no matching edges found for your incoming #{magnetic_to} => #{edge_color}")
            open_incoming_lines << [node, Output.new(nil, edge_color)] # fixme: THIS IS AN INPUT
          end

          # connect this new `node` to all magnetic, open edges.
          incoming_lines.each do |line|
            circuit_hash[ line.source ][ line.output.signal ] = node
            circuit_hash[ node ] ||= {} # DISCUSS: or needed?
          end

          outputs.each do |output|
            open_outputs= open_incoming_lines.pop(output.role)
            if open_outputs.any?

              # connect this new `node` to all magnetic, open edges.
              open_outputs.each do |line|
                circuit_hash[ node ][ output.signal ] = line.source
                circuit_hash[ node ] ||= {} # DISCUSS: or needed?
              end
            else
              open_outgoing_lines << [node, output]
            end
          end
        end
      end

      circuit_hash
    end
  end

end
