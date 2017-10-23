require "test_helper"

class DrawGraphTest < Minitest::Spec
  Right = Circuit::Right
  Left  = Circuit::Left
  # Z = "bla"

  S = ->(*) { snippet }

  A = ->(*) { snippet }
  E = ->(*) { snippet }
  B = ->(*) { snippet }
  C = ->(*) { snippet }
  F = ->(*) { snippet }

  ES = ->(*) { snippet }
  EF = ->(*) { snippet }
=begin
[
  S: -R>
  R> A: -R> -L> a is magnetic to R (incoming)
]
=end

  let(:start_evt)     { Trailblazer::Activity::Graph::Start(S) }

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

  R = Output.new(Right, :success)
  L = Output.new(Left,  :failure)
  Z = Output.new("bla", :my_z)

  it do
    steps = [
      #  magnetic to
      #  color | signal|outputs
      [ [:success], A,  [R, L] ],
      [ [:failure], E, [] ],
      [ [:success], B, [R, L] ],
      [ [:success], C, [R, L] ],
      [ [:failure], F, [L, Z] ],
        [ [:my_z], S, [] ], # "connect"


      [ [:success], ES, [] ],
      [ [:failure], EF, [] ],
    ]

    added_tasks      = {}
    open_lines = OpenLines.new
    open_lines << [start_evt, R]

    steps.each do |(magnetic_to, node, outputs)|
      puts "drawing #{node} which wants #{magnetic_to}"
      new_node = nil

      magnetic_to.each do |signal|
        connection_lines = open_lines.pop(signal) || raise("no matching edges found for your incoming #{magnetic_to}")

        # connect this new node to all magnetic, open edges.
        connection_lines.each do |line|
          command, existing_node = added_tasks[node] ? [ :connect!, added_tasks[node] ] : [ :attach!, [node, id: node] ]

          new_node, edge = start_evt.send(
            command, # attach! or connect!
            source: line.source,
            target: existing_node,
            edge:   [ line.output.signal, {} ]
          )

          added_tasks[node] = new_node #
        end

        outputs.each do |output|
          open_lines << [new_node, output]
        end

      end
    end

    pp start_evt.to_h
  end
end
