module Trailblazer
  # Schema helps you managing the construction of an {Activity}.
  # It is used in the Operation and Activity DSL, and also for the TaskWrap.
  # A Schema always produces an Activity.
  #
  # only knows about PlusPole
  class Activity::Schema
    module Magnetic

      Line   = Struct.new(:source, :output)

      class OpenLines
        def initialize
          @arr = []
        end

        def pop(signal, &block)
          lines = @arr.find_all { |line| line.output.color == signal }
          @arr -= lines

          lines.each(&block)
          lines.any?
        end

        def <<((node, output))
          @arr << Line.new(node, output)
        end
      end

      def self.call(tasks, start_events: [Circuit::Start.new(:default)])
        open_plus_poles = OpenLines.new
        open_minus_poles    = OpenLines.new
        circuit_hash        = {}

        start_tasks = start_events.collect do |evt|
          [ [], evt, [ Activity::Magnetic::PlusPole.new(Activity::Magnetic::Output(Circuit::Right, :success), :success) ] ]
        end

        (start_tasks + tasks).each do |(magnetic_to, node, outputs)|
          circuit_hash[ node ] ||= {} # DISCUSS: or needed?

          magnetic_to.each do |edge_color| # minus poles
            open_plus_poles.pop(edge_color) do |line|
              connect( circuit_hash, line.source, line.output.signal, node )
            end and next

            # only run when there were no open_minus_poles
            open_minus_poles << [node, Activity::Magnetic::PlusPole.new(nil, edge_color)] # fixme: THIS IS AN INPUT
          end

          outputs.each do |output|
            open_minus_poles.pop(output.color) do |line|
              connect( circuit_hash, node, output.signal, line.source )
            end and next

            # only run when there were no open_plus_poles
            open_plus_poles << [node, output]
          end
        end

        circuit_hash
      end

      #                               plus            minus
      def self.connect(circuit_hash, source, signal, target)
        circuit_hash[ source ][ signal ] = target
      end
    end # Magnetic
  end
end
