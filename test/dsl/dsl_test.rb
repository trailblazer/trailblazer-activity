require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right


  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  # Activity.plan( track_color: :pink )
  it "unit test" do
    block = -> do
      task J, id: "report_invalid_result"
      task K, id: "log_invalid_result", Output(Right, :success) => End("End.invalid_result", :invalid_result)
    end

    seq = Activity.plan(track_color: :"track_9", &block)

    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> "ActivityBuildTest::K-Trailblazer::Circuit::Right"
[:track_9] ==> #<End:track_9>
 []
["ActivityBuildTest::K-Trailblazer::Circuit::Right"] ==> #<End:End.invalid_result>
 []
}
  end

  # 3 ends, 1 of 'em default.
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "extract",  Output(Left, :failure) => End("End.extract.key_not_found", :key_not_found)
      task K, id: "validate", Output(Left, :failure) => End("End.invalid", :invalid)
      # TODO: task ==> End.track_9
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> "ActivityBuildTest::J-Trailblazer::Circuit::Left"
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
 (failure)/Left ==> "ActivityBuildTest::K-Trailblazer::Circuit::Left"
[:track_9] ==> #<End:track_9>
 []
["ActivityBuildTest::J-Trailblazer::Circuit::Left"] ==> #<End:End.extract.key_not_found>
 []
["ActivityBuildTest::K-Trailblazer::Circuit::Left"] ==> #<End:End.invalid>
 []
}
  end

  # straight path with different name for :success.
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "first"
      task K, id: "last"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
}
  end

  # some new Output
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "confused", Output(Left, :failure) => :success__
      task K, id: "normal"
      # TODO: task ==> End.track_9
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> :success__
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
}
  end

  # activity with 1 output, AND 1 new Output, connected to existing track_9 edge
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "confused", Output(Left, :failure) => :"track_9"
      task K, id: "normal"
      # TODO: task ==> End.track_9
    end

# puts Seq(seq)
    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (success)/Right ==> :track_9
 (failure)/Left ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
}
  end

  # Activity with 2 predefined outputs, direct 2nd one to new end
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "confused",
        Output(Left, :trigger) => End("End.trigger", :triggered),
        # this comes from the Operation DSL since it knows {Activity}J
        plus_poles: Activity::Magnetic::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Left,  :trigger) => nil,
          Activity::Magnetic.Output(Circuit::Right, :success) => nil,
        ).freeze
      task K, id: "normal"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "ActivityBuildTest::J-Trailblazer::Circuit::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
["ActivityBuildTest::J-Trailblazer::Circuit::Left"] ==> #<End:End.trigger>
 []
}
  end
  # Activity with 2 predefined outputs, direct 2nd one to new end without Output
  it do
    seq = Activity.plan(track_color: :"track_9") do
      task J, id: "confused",
        Output(:trigger) => End("End.trigger", :triggered),
        # this comes from the Operation DSL since it knows {Activity}J
        plus_poles: Activity::Magnetic::PlusPoles.new.merge(
          Activity::Magnetic.Output(Circuit::Left,  :trigger) => nil,
          Activity::Magnetic.Output(Circuit::Right, :success) => nil,
        ).freeze
      task K, id: "normal"
    end

    Seq(seq).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::J
 (trigger)/Left ==> "ActivityBuildTest::J-Trailblazer::Circuit::Left"
 (success)/Right ==> :track_9
[:track_9] ==> ActivityBuildTest::K
 (success)/Right ==> :track_9
[:track_9] ==> #<End:track_9>
 []
["ActivityBuildTest::J-Trailblazer::Circuit::Left"] ==> #<End:End.trigger>
 []
}
  end

  # Activity with 2 predefined outputs, direct 2nd one to same end


  it do
    tripletts = Activity.plan do
      # task Task(), id: :inquiry_create, Left => :suspend_for_correct
      #   task Task(), id: :suspend_for_correct, Right => :inquiry_create
      # task Task(), id: :notify_pickup
      # task Task(), id: :suspend_for_pickup

      # task Task(), id: :pickup
      # task Task(), id: :suspend_for_process_id

      task G, id: :receive_process_id#, Output(Right, :success) => :success
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Right, :success) => :success, Output(Left, :failure) => -> do
        task J, id: "report_invalid_result"
        # task K, id: "log_invalid_result", Output(Right, :success) => color
        task K, id: "log_invalid_result", Output(Right, :success) => End("End.invalid_result", :invalid_result)
      end

      task L, id: :notify_clerk#, Output(Right, :success) => :success
    end

    # puts Seq(activity)
#     Seq(activity).must_equal %{
# [] ==> #<Start:default>
#  (success)/Right ==> :success
# [:success] ==> ActivityBuildTest::G
#  (success)/Right ==> :success
# [:success] ==> ActivityBuildTest::I
#  (success)/Right ==> :success
#  (failure)/Left ==> "track_0.7043767456808654"
# ["track_0.7043767456808654"] ==> ActivityBuildTest::J
#  (success)/Right ==> "track_0.7043767456808654"
# ["track_0.7043767456808654"] ==> ActivityBuildTest::K
#  (success)/Right ==> "ActivityBuildTest::K-Trailblazer::Circuit::Right"
# ["track_0.7043767456808654"] ==> #<End:success>
#  []
# ["ActivityBuildTest::K-Trailblazer::Circuit::Right"] ==> #<End:End.invalid_result>
#  []
# [:success] ==> ActivityBuildTest::L
#  (success)/Right ==> :success
# [:success] ==> #<End:success>
#  []
# }

circuit_hash = Trailblazer::Activity::Schema::Magnetic.( tripletts )

pp circuit_hash

puts Cct(circuit_hash)
    Cct(circuit_hash).sub(/\d\d+/, "").must_equal %{
#<Start:default>
 {Trailblazer::Circuit::Right} => ActivityBuildTest::G
ActivityBuildTest::G
 {Trailblazer::Circuit::Right} => ActivityBuildTest::I
ActivityBuildTest::I
 {Trailblazer::Circuit::Left} => ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::L
ActivityBuildTest::J
 {Trailblazer::Circuit::Right} => ActivityBuildTest::K
ActivityBuildTest::K
 {Trailblazer::Circuit::Right} => #<End:End.invalid_result>
#<End:track_0.>

#<End:End.invalid_result>

ActivityBuildTest::L
 {Trailblazer::Circuit::Right} => #<End:success>
#<End:success>
}

    activity.outputs.must_equal()
  end

  # defaults
  it do
    activity = Activity.plan do
      # task Task(), id: :inquiry_create, Left => :suspend_for_correct
      #   task Task(), id: :suspend_for_correct, Right => :inquiry_create
      # task Task(), id: :notify_pickup
      # task Task(), id: :suspend_for_pickup

      # task Task(), id: :pickup
      # task Task(), id: :suspend_for_process_id

      task G, id: :receive_process_id
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Left, :failure) => ->(color) do

                                                  # means: :success => "report_invalid_result"-End.invalid_result"
        task J, id: "report_invalid_result", Output(Right, :success) => color
        # task K, id: "log_invalid_result", Output(Right, :success) => color
        task K, id: "log_invalid_result", Output(Right, :success) =>
          End("End.invalid_result", :invalid_result)
      end

      task L, id: :notify_clerk
    end

    puts Inspect(activity).must_equal %{{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>ActivityBuildTest::G}, ActivityBuildTest::G=>{Trailblazer::Circuit::Right=>ActivityBuildTest::I}, ActivityBuildTest::I=>{Trailblazer::Circuit::Left=>ActivityBuildTest::J, Trailblazer::Circuit::Right=>ActivityBuildTest::L}, ActivityBuildTest::J=>{Trailblazer::Circuit::Right=>ActivityBuildTest::K}, ActivityBuildTest::K=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name=\"End.invalid_result\", @options={}>}, ActivityBuildTest::L=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name=:success, @options={}>}, #<Trailblazer::Circuit::End: @name=:success, @options={}>=>{}, #<Trailblazer::Circuit::End: @name=\"End.invalid_result\", @options={}>=>{}}}
  end

  require "trailblazer/activity/dsl/railway"
  it "what" do
    initial_plus_poles = Activity::Magnetic::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      Activity::Magnetic.Output("Signal A", :exception)  => :exception,
      Activity::Magnetic.Output(Circuit::Left, :failure) => :failure )

    seq = Activity::DSL.alter_sequence(
      Activity::Magnetic::Alterations.new,
      G,
        id: :receive_process_id,
        strategy: [
          Activity::DSL::PoleGenerator::FastTrack.method(:step),
          plus_poles: initial_plus_poles,
        ],

        # existing success to new end
        Activity::Magnetic.Output(Right, :success) => Circuit::End.new("End.invalid_result"),

        Activity::Magnetic.Output("Signal A", :exception) => Circuit::End.new("End.signal_a_reached"),
     )

    pp seq
    Inspect(seq).must_equal %{#<Trailblazer::Activity::Magnetic::Alterations: @groups=#<Trailblazer::Activity::Schema::Magnetic::Dependencies: @groups={:start=>[], :main=>[#<struct Trailblazer::Activity::Schema::Sequence::Element id=\"ActivityBuildTest::G\", configuration=[[:success], ActivityBuildTest::G, [#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=\"ActivityBuildTest::G-Trailblazer::Circuit::Right\">, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=\"Signal A\", semantic=:exception>, color=\"ActivityBuildTest::G-Signal A\">, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:failure>]]>], :end=>[#<struct Trailblazer::Activity::Schema::Sequence::Element id=\"End.invalid_result\", configuration=[[\"ActivityBuildTest::G-Trailblazer::Circuit::Right\"], #<Trailblazer::Circuit::End: @name=\"End.invalid_result\", @options={}>, []]>, #<struct Trailblazer::Activity::Schema::Sequence::Element id=\"End.signal_a_reached\", configuration=[[\"ActivityBuildTest::G-Signal A\"], #<Trailblazer::Circuit::End: @name=\"End.signal_a_reached\", @options={}>, []]>], :unresolved=>[]}, @order=[:start, :main, :end, :unresolved]>, @future_magnetic_to={}>}
  end


  let(:initial_plus_poles) do
    Activity::Magnetic::PlusPoles.new.merge(
      Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      # Activity::Magnetic.Output("Signal A", :exception)  => :exception,
      Activity::Magnetic.Output(Circuit::Left, :failure) => :failure
    )
  end

  it "builder API, what we use in Operation" do
    # this is what happens in Operation.
    incremental = Activity::FastTrack::Builder.new( track_color: :pink, failure_color: :black )
    incremental.step G, id: :G, plus_poles: initial_plus_poles, fail_fast: true # these options we WANT built by Operation (task, id, plus_poles)
    incremental.step I, id: :I, plus_poles: initial_plus_poles
    incremental.fail J, id: :J, plus_poles: initial_plus_poles
    incremental.pass K, id: :K, plus_poles: initial_plus_poles

    sequence = incremental.draft
    pp sequence

    Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :pink
[:pink] ==> ActivityBuildTest::G
 (success)/Right ==> :pink
 (failure)/Left ==> :fail_fast
[:pink] ==> ActivityBuildTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> :black
[:black] ==> ActivityBuildTest::J
 (success)/Right ==> :black
 (failure)/Left ==> :black
[:pink] ==> ActivityBuildTest::K
 (success)/Right ==> :pink
 (failure)/Left ==> :pink
[:pink] ==> #<End:pink>
 []
[:black] ==> #<End:failure>
 []
[:fail_fast] ==> #<End:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast>
 []
}

    activity = incremental.finalize

    # pp activity
  end

  # hand additional DSL options
  it do
    # this is what happens in Operation.
    incremental = Activity::FastTrack::Builder.new( track_color: :pink, failure_color: :black )
    incremental.step G, id: :G, plus_poles: initial_plus_poles, fail_fast: true, Activity::Magnetic.Output("Exception", :exception) => Circuit::End(:exception)
    incremental.step I, id: :I, plus_poles: initial_plus_poles
    incremental.fail J, id: :J, plus_poles: initial_plus_poles
    incremental.pass K, id: :K, plus_poles: initial_plus_poles

    sequence = incremental.draft
    # pp sequence
# puts Seq(sequence)
    Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :pink
[:pink] ==> ActivityBuildTest::G
 (success)/Right ==> :pink
 (failure)/Left ==> :fail_fast
 (exception)/Exception ==> "ActivityBuildTest::G-Exception"
[:pink] ==> ActivityBuildTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> :black
[:black] ==> ActivityBuildTest::J
 (success)/Right ==> :black
 (failure)/Left ==> :black
[:pink] ==> ActivityBuildTest::K
 (success)/Right ==> :pink
 (failure)/Left ==> :pink
[:pink] ==> #<End:pink>
 []
[:black] ==> #<End:failure>
 []
[:fail_fast] ==> #<End:fail_fast>
 []
[:pass_fast] ==> #<End:pass_fast>
 []
["ActivityBuildTest::G-Exception"] ==> #<End:exception>
 []
}
  end

  describe "Path::Builder" do
    let(:initial_plus_poles) do
      Activity::Magnetic::PlusPoles.new.merge(
        Activity::Magnetic.Output(Circuit::Right, :success) => :success,
      )
    end

    # with all options.
    it do
      incremental = Activity::Path::Builder.new( track_color: :pink )
      incremental.task G, id: G, plus_poles: initial_plus_poles, Activity::Magnetic.Output("Exception", :exception) => Circuit::End(:exception)
      incremental.task I, id: I, plus_poles: initial_plus_poles, Activity::Magnetic.Output(Circuit::Left, :failure) => Circuit::End(:failure)

      sequence = incremental.draft

      Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :pink
[:pink] ==> ActivityBuildTest::G
 (success)/Right ==> :pink
 (exception)/Exception ==> "ActivityBuildTest::G-Exception"
[:pink] ==> ActivityBuildTest::I
 (success)/Right ==> :pink
 (failure)/Left ==> "ActivityBuildTest::I-Trailblazer::Circuit::Left"
[:pink] ==> #<End:pink>
 []
["ActivityBuildTest::G-Exception"] ==> #<End:exception>
 []
["ActivityBuildTest::I-Trailblazer::Circuit::Left"] ==> #<End:failure>
 []
}
    end

    # with plus_poles.
    it do
      incremental = Activity::Path::Builder.new( plus_poles: initial_plus_poles )
      incremental.task G, id: G, Activity::Magnetic.Output("Exception", :exception) => Circuit::End(:exception)
      incremental.task I, id: I, Activity::Magnetic.Output(Circuit::Left, :failure) => Circuit::End(:failure)

      sequence = incremental.draft

      Seq(sequence).must_equal %{
[] ==> #<Start:default>
 (success)/Right ==> :success
[:success] ==> ActivityBuildTest::G
 (success)/Right ==> :success
 (exception)/Exception ==> "ActivityBuildTest::G-Exception"
[:success] ==> ActivityBuildTest::I
 (success)/Right ==> :success
 (failure)/Left ==> "ActivityBuildTest::I-Trailblazer::Circuit::Left"
[:success] ==> #<End:success>
 []
["ActivityBuildTest::G-Exception"] ==> #<End:exception>
 []
["ActivityBuildTest::I-Trailblazer::Circuit::Left"] ==> #<End:failure>
 []
}
    end
  end
end


