require "test_helper"

class DrawGraphTest < Minitest::Spec
  Right = Activity::Right
  Left  = Activity::Left
  # Z = "bla"

  class S; end
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

  Magnetic = Trailblazer::Activity::Magnetic

  R = Magnetic::PlusPole.new( Activity.Output(Right, :success), :success )
  L = Magnetic::PlusPole.new( Activity.Output(Left,  :failure), :failure )
  Z = Magnetic::PlusPole.new( Activity.Output("bla", :my_z), :my_z )

  it do
    tripletts = [
      #  magnetic to
      #  color | signal|outputs
      [ [], A,  [R, L] ],
      [ [:failure], E, [] ],
      [ [:success], B, [R, L] ],
      [ [:success], C, [R, L] ],
      [ [:failure], F, [L, Z] ],
        [ [:my_z], S, [] ], # "connect"


      [ [:success], ES, [] ],
      [ [:failure], EF, [] ],
    ]

    hash = Trailblazer::Activity::Magnetic::Builder::Finalizer.tripletts_to_circuit_hash( tripletts )

    circuit_hash(hash).must_equal %{
DrawGraphTest::A
 {Trailblazer::Activity::Left} => DrawGraphTest::E
 {Trailblazer::Activity::Right} => DrawGraphTest::B
DrawGraphTest::E

DrawGraphTest::B
 {Trailblazer::Activity::Right} => DrawGraphTest::C
 {Trailblazer::Activity::Left} => DrawGraphTest::F
DrawGraphTest::C
 {Trailblazer::Activity::Left} => DrawGraphTest::F
 {Trailblazer::Activity::Right} => DrawGraphTest::ES
DrawGraphTest::F
 {bla} => DrawGraphTest::S
 {Trailblazer::Activity::Left} => DrawGraphTest::EF
DrawGraphTest::S

DrawGraphTest::ES

DrawGraphTest::EF
}
  end

  # A points to C
  it do
    tripletts = [
      #  magnetic to
      #  color | signal|outputs
      [ [], A,  [ Z, L ] ],
      [ [], B, [R, L] ],
      [ [:success, :my_z], C, [R, L] ],

      [ [:success], ES, [] ],
      [ [:failure], EF, [] ],
    ]

    hash = Trailblazer::Activity::Magnetic::Builder::Finalizer.tripletts_to_circuit_hash( tripletts )

    circuit_hash(hash).gsub(/0x\w+/, "").must_equal %{
DrawGraphTest::A
 {bla} => DrawGraphTest::C
 {Trailblazer::Activity::Left} => DrawGraphTest::EF
DrawGraphTest::B
 {Trailblazer::Activity::Right} => DrawGraphTest::C
 {Trailblazer::Activity::Left} => DrawGraphTest::EF
DrawGraphTest::C
 {Trailblazer::Activity::Right} => DrawGraphTest::ES
 {Trailblazer::Activity::Left} => DrawGraphTest::EF
DrawGraphTest::ES

DrawGraphTest::EF
}
  end

  # circular
  it do
    tripletts = [
      [ [:to_a], A, [ R, Magnetic::PlusPole.new( Activity.Output("SIG", :to_a), :to_a) ] ],
      [ [:success], B, [ R ] ],

      [ [:success], ES, [] ],
      [ [:failure], EF, [] ],
    ]

    hash = Trailblazer::Activity::Magnetic::Builder::Finalizer.tripletts_to_circuit_hash( tripletts )

   circuit_hash(hash).gsub(/0x\w+/, "").must_equal %{
DrawGraphTest::A
 {SIG} => DrawGraphTest::A
 {Trailblazer::Activity::Right} => DrawGraphTest::B
DrawGraphTest::B
 {Trailblazer::Activity::Right} => DrawGraphTest::ES
DrawGraphTest::ES

DrawGraphTest::EF
}
  end

  describe "referencing a task coming ahead" do
    it do
      normalizer, _ = Magnetic::Normalizer.build(outputs: Magnetic::Builder::Railway.default_outputs)

      builder, adds, _ = Activity::Magnetic::Builder::State.build( Magnetic::Builder::Path, normalizer, {} )

      _, adds, _       = Activity::Magnetic::Builder::State.add( builder, adds, Activity::Magnetic::Builder::Path, :TaskPolarizations, :task, {task: A, Activity::DSL::Helper.Output(:success) => "find"}, {} )
      _, adds, _       = Activity::Magnetic::Builder::State.add( builder, adds, Activity::Magnetic::Builder::Path, :TaskPolarizations, :task, {task: :Find, id: "find"}, {} )

      # pp adds

      # without magnetic_to: [], Find will reference itself due to the Finalizer algorithm.
      activity, _ = Trailblazer::Activity::Magnetic::Builder::Finalizer.( adds )

     Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => DrawGraphTest::A
DrawGraphTest::A
 {Trailblazer::Activity::Right} => :Find
:Find
 {Trailblazer::Activity::Right} => :Find
#<End/:success>
}
    end
  end

  describe "Alterations" do
    it do
      skip "please unit-test Alterations"
      alterations = Trailblazer::Activity::Magnetic::DSL::Alterations.new

      # happens in Operation::initialize_sequence
      alterations.add( :EF,  [ [:failure], EF, {} ], group: :end )
      alterations.add( :ES,  [ [:success], ES, {} ], group: :end )

      # step A
      alterations.add( :A,   [ [:success], A, [ Activity.Output(Right, :success), Activity.Output(Left, :failure) ] ] )

      # fail E, success: "End.success"
      alterations.add( :E,   [ [:failure], E, [ Activity.Output(Right, :failure, :success), Activity.Output(Left, :failure) ] ], )
      alterations.connect_to( :E, { success: "e_to_success" } )
      alterations.magnetic_to( :ES, ["e_to_success"] ) # existing target: add a "magnetic_to" to it!



      graph, _     = Trailblazer::Activity::Magnetic::Finalizer.( alterations.to_a )

puts graph

      Inspect(graph.inspect).must_equal %{"{#<Trailblazer::Activity::Start: @name=:default, @options={}>=>{Trailblazer::Activity::Right=>DrawGraphTest::A}, DrawGraphTest::A=>{Trailblazer::Activity::Left=>DrawGraphTest::E, Trailblazer::Activity::Right=>DrawGraphTest::ES}, DrawGraphTest::E=>{Trailblazer::Activity::Left=>DrawGraphTest::EF, Trailblazer::Activity::Right=>DrawGraphTest::ES}, DrawGraphTest::EF=>{}, DrawGraphTest::ES=>{}}"}
    end
  end

  it do
    dependencies = Trailblazer::Activity::Schema::Dependencies.new

    # happens in Operation::initialize_sequence
    dependencies.add( :EF,  [ [:failure], EF, [] ], group: :end )
    dependencies.add( :ES,  [ [:success], ES, [] ], group: :end )

    dependencies.add( :A,   [ [:success], A,  [R, L] ] )

    dependencies.add( :ES,  [ [:another_success], ES, [] ] ) # extend existing input.


    sequence = dependencies.to_a

    sequence.inspect.must_equal %{[[[:success], DrawGraphTest::A, [#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Left, semantic=:failure>, color=:failure>]], [[:another_success], DrawGraphTest::ES, []], [[:failure], DrawGraphTest::EF, []], [[:success], DrawGraphTest::ES, []]]}
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
