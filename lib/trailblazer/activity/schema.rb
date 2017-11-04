module Trailblazer
  # Schema helps you managing the construction of an {Activity}.
  # It is used in the Operation and Activity DSL, and also for the TaskWrap.
  # A Schema always produces an Activity.
  class Activity::Schema
    Output = Struct.new(:signal, :color)
    Line   = Struct.new(:source, :output)

    class OpenLines
      def initialize
        @arr = []
      end

      def pop(signal)
        lines = @arr.find_all { |line| line.output.color == signal }
        @arr -= lines
        lines
      end

      def <<((node, output))
        @arr << Line.new(node, output)
      end
    end

    def self.bla(tasks, start_events: [Circuit::Start.new(:default)])
      open_outgoing_lines = OpenLines.new
      open_minus_poles    = OpenLines.new
      circuit_hash        = {}

      start_events.each do |evt|
        circuit_hash[evt] = {}
        open_outgoing_lines << [ evt, Output.new(Circuit::Right, :success) ]
      end

      tasks.each do |(magnetic_to, node, outputs)|
        puts "~~~~~~~~~ drawing #{node} which wants #{magnetic_to}"

        circuit_hash[ node ] ||= {} # DISCUSS: or needed?

        magnetic_to.each do |edge_color| # minus poles
          plus_poles = open_outgoing_lines.pop(edge_color)

          if plus_poles.any?
            # connect this new `node` to all magnetic, open edges.
            plus_poles.each do |line|
              connect( circuit_hash, line.source, line.output.signal, node )
            end
          else
            puts("no matching edges found for your incoming #{magnetic_to} => #{edge_color}")
            open_minus_poles << [node, Output.new(nil, edge_color)] # fixme: THIS IS AN INPUT
          end

        end

        outputs.each do |output|
          minus_poles= open_minus_poles.pop(output.color)

          if minus_poles.any?
            # connect this new `node` to all magnetic, open edges.
            minus_poles.each do |line|
              connect( circuit_hash, node, output.signal, line.source )
            end
          else
            open_outgoing_lines << [node, output]
          end
        end
      end

      circuit_hash
    end

    #                               plus            minus
    def self.connect(circuit_hash, source, signal, target)
      circuit_hash[ source ][ signal ] = target
    end

  end
end
