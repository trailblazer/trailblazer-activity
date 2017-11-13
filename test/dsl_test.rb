require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right


  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  it "unit test" do
    sequence=Activity::Magnetic::Alterations.new

    block = ->(color) do
      task J, id: "report_invalid_result", Output(Right, :success) => color
      # task K, id: "log_invalid_result", Output(Right, :success) => color
      task K, id: "log_invalid_result", Output(Right, :success) =>
        End("End.invalid_result", :invalid_result)
    end

    dsl = Activity::DSL.new(sequence, color = :"track_#{rand}")

    seq = dsl.instance_exec(color, &block)

    pp seq
  end


  it do
    activity = Activity.build do
      # task Task(), id: :inquiry_create, Left => :suspend_for_correct
      #   task Task(), id: :suspend_for_correct, Right => :inquiry_create
      # task Task(), id: :notify_pickup
      # task Task(), id: :suspend_for_pickup

      # task Task(), id: :pickup
      # task Task(), id: :suspend_for_process_id

      task G, id: :receive_process_id, Output(Right, :success) => :success
      # task Task(), id: :suspend_wait_for_result

      task I, id: :process_result, Output(Right, :success) => :success, Output(Left, :failure) => ->(color) do

                                                  # means: :success => "report_invalid_result"-End.invalid_result"
        task J, id: "report_invalid_result", Output(Right, :success) => color
        # task K, id: "log_invalid_result", Output(Right, :success) => color
        task K, id: "log_invalid_result", Output(Right, :success) =>
          End("End.invalid_result", :invalid_result)
      end

      task L, id: :notify_clerk, Output(Right, :success) => :success
    end

    pp activity

    Inspect(activity).must_equal %{{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>ActivityBuildTest::G}, ActivityBuildTest::G=>{Trailblazer::Circuit::Right=>ActivityBuildTest::I}, ActivityBuildTest::I=>{Trailblazer::Circuit::Left=>ActivityBuildTest::J, Trailblazer::Circuit::Right=>ActivityBuildTest::L}, ActivityBuildTest::J=>{Trailblazer::Circuit::Right=>ActivityBuildTest::K}, ActivityBuildTest::K=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name=\"End.invalid_result\", @options={}>}, ActivityBuildTest::L=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name=:success, @options={}>}, #<Trailblazer::Circuit::End: @name=\"End.invalid_result\", @options={}>=>{}, #<Trailblazer::Circuit::End: @name=:success, @options={}>=>{}}}
  end


  # defaults
  it do
    activity = Activity.build do
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

    puts Inspect(activity).must_equal %{{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>ActivityBuildTest::G}, ActivityBuildTest::G=>{Trailblazer::Circuit::Right=>ActivityBuildTest::I}, ActivityBuildTest::I=>{Trailblazer::Circuit::Left=>ActivityBuildTest::J, Trailblazer::Circuit::Right=>ActivityBuildTest::L}, ActivityBuildTest::J=>{Trailblazer::Circuit::Right=>ActivityBuildTest::K}, ActivityBuildTest::K=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name="End.invalid_result", @options={}>}, ActivityBuildTest::L=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name=:success, @options={}>}, #<Trailblazer::Circuit::End: @name="End.invalid_result", @options={}>=>{}, #<Trailblazer::Circuit::End: @name=:success, @options={}>=>{}}}
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

end


