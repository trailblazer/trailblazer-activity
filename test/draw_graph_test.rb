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

  # Mutable object to track what open lines are waiting to be connected
  # to a node.


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

    bla = Trailblazer::Activity::Schema.bla(steps)


    pp bla.to_h
  end
end
