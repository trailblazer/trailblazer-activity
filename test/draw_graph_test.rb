require "test_helper"

require "trailblazer/activity/schema/magnetic"
require "trailblazer/activity/schema/dependencies"

class DrawGraphTest < Minitest::Spec
  Right = Circuit::Right
  Left  = Circuit::Left
  # Z = "bla"

  S = ->(*) { snippet }

  class A; end
  class E; end
  class B; end
  class C; end
  class F; end

  class ES; end
  class EF; end
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
    b_to_a = Output.new("bla", :b_to_a) # mapping Output
    # e_to_success = Output::OpenLine.new(Right, :e_to_success)


    dependencies = Trailblazer::Activity::Schema::Magnetic::Dependencies.new

    # happens in Operation::initialize_sequence
    dependencies.add( :EF,  [ [:failure], EF, [] ], group: :end )
    dependencies.add( :ES,  [ [:success], ES, [] ], group: :end )

    # step A
    dependencies.add( :A,   [ [:success], A,  [R, L] ] )

    # fail E, success: "End.success"
    dependencies.add( :E,   [ [:failure], E, [L, e_to_success] ], )
    dependencies.add( :ES,  [ [:e_to_success], ES, [] ], group: :end ) # existing target: add a "magnetic_to" to it!

    pp steps = dependencies.to_a

=begin
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
=end

    bla = Trailblazer::Activity::Schema::Magnetic.(steps)


    pp bla.to_h


    dependencies.add( :C, [ [:success], C, [R, L] ] ) # after A
    dependencies.add( :B, [ [:success], B, [R, L] ], after: :A )

    # now, connect B to A //    or FIXME:Start
    # no idea, how would the DSL call look here?
    dependencies.add( :B, [ [], B, [b_to_a] ], group: :unresolved )  # "b has additional output"
    dependencies.add( :A, [ [:b_to_a], A, [] ], group: :unresolved ) # "a has additional input"


    pp steps = dependencies.to_a
    bla = Trailblazer::Activity::Schema.bla(steps)
    pp bla.to_h
  end

  it do
    dependencies = Trailblazer::Activity::Schema::Magnetic::Dependencies.new

    # happens in Operation::initialize_sequence
    dependencies.add( :EF,  [ [:failure], EF, [] ], group: :end )
    dependencies.add( :ES,  [ [:success], ES, [] ], group: :end )

    dependencies.add( :A,   [ [:success], A,  [R, L] ] )

    dependencies.add( :ES,  [ [:another_success], ES, [] ] ) # extend existing input.

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

=begin
Sequence::Dependencies.new
  .add Policy, id: "Policy", group: :prepend, // magnetic_to: [Input(:success), Input("Policy")], ...

[
  [{prepend}
    prepend!, Policy, magnetic_to: [Input(:success), Input("Policy")]
  ],
  [{step}
    insert!, A,                          Output(Right, :success), Output(Left, :failure)
    insert!, B,
    insert!, C, :success => End.special # will have special edge, not :railway ===>
                Output(Right, "End.special")
  ],
  [{end/append}
    append!, End.success,
    append!, End.failure,
    append!, End.pass_fast,  magnetic_to: Input(:success, "End.success")
    append!, End.special, magnetic_to: Input("End.special")
  ],
  [{unresolved}
    insert, F, before: End.success
  ]
]

=> Sequence

=> Instructions (for Drawer)
  here we need to take care of things like C has special color edge to End.special
=end
