require "test_helper"

class DrawGraphTest < Minitest::Spec
  R = Circuit::Right
  L = Circuit::Left
  Z = "bla"

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

  it do
    steps = [
      [ [R], A, [R, L] ],
      [ [L], E, [] ],
      [ [R], B, [R, L] ],
      [ [R], C, [R, L] ],
      [ [L], F, [L, Z] ],
        [ [Z], S, [] ], # "connect"


      [ [R], ES, [] ],
      [ [L], EF, [] ],
    ]

    added_tasks      = {}
    open_lines = { R => [ start_evt ] }

    steps.each do |(magnetic_to, node, outgoing_lines)|
      puts "drawing #{node} which wants #{magnetic_to}"
      # new_node = start_evt.Node(  )
      new_node = nil

      magnetic_to.each do |signal|
        connect_to = open_lines.delete(signal) || raise("no matching edges found for your incoming #{magnetic_to}")

        # connect this new node to all magnetic, open edges.
        connect_to.each do |source_node|
          command, existing_node = added_tasks[node] ? [ :connect!, added_tasks[node] ] : [ :attach!, [node, id: node] ]

          new_node, edge = start_evt.send(
            command, # attach! or connect!
            source: source_node,
            target: existing_node,
            edge:   [ signal, {} ]
          )

          added_tasks[node] = new_node #
        end

        outgoing_lines.each do |signal|
          open_lines[signal] ||= []
          open_lines[signal] << new_node
        end

      end
    end

    pp start_evt.to_h
  end
end
