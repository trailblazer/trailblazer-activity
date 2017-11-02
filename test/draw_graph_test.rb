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


  # Mutable object to track what open lines are waiting to be connected
  # to a node.

  Output = Trailblazer::Activity::Schema::Output

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

  it do
    ## actual output from E: (Left, :failure), (Right, :failure)

    # Output: {Right, :success} where :success is a hint on the meaning.
    # Line: {source, output, :magnetic_to} where output is the originally mapped output (for the signal), and magnetic_to is our new polarization,
    # eg. when you want to map failure to success or whatever

=begin
    from ::pass
      Task::Free{ <=magnetic_to, callable_thing, id, =>outputs{ Right=>:success,Left=>:myerrorhandler, original[(Right, :success),(Left, :success)] } }
=end

    e_to_success = Output.new(Right, :e_to_success) # mapping Output
    # e_to_success = Output::OpenLine.new(Right, :e_to_success)


    steps = [
      #  magnetic to
      #  color | signal|outputs
      [ [:success], A,  [R, L] ],
      [ [:failure], E, [L, e_to_success] ],
      [ [:success], B, [R, L] ],
      [ [:success], C, [R] ],

      [ [:success, :e_to_success], ES, [] ], # magnetic_to needs to have the special line, too.
      [ [:failure], EF, [] ],
    ]

    bla = Trailblazer::Activity::Schema.bla(steps)


    pp bla.to_h
  end
end



# * graph API is too low-level


# deleting
# "groups": insert before bla


# FAST_TRACK:
#  => add Output::Line instance(s) to outgoing                 before insert!ing on the Sequence
#  => add resp ends (:pass_fast, End::PassFast.new, [])        when do we do this? "override Sequence#to_a ?"


=begin
seq = Seq.new
 .insert!
 .insert! right_before: end_fail
 .insert!
 .insert!
 .insert! end_fail
 .insert! end_success
=end
