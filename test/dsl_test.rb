require "test_helper"

class ActivityBuildTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right


  class G; end
  class I; end
  class J; end
  class K; end
  class L; end


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

    puts Inspect(activity).must_equal %{{#<Trailblazer::Circuit::Start: @name=:default, @options={}>=>{Trailblazer::Circuit::Right=>ActivityBuildTest::G}, ActivityBuildTest::G=>{Trailblazer::Circuit::Right=>ActivityBuildTest::I}, ActivityBuildTest::I=>{Trailblazer::Circuit::Left=>ActivityBuildTest::J, Trailblazer::Circuit::Right=>ActivityBuildTest::L}, ActivityBuildTest::J=>{Trailblazer::Circuit::Right=>ActivityBuildTest::K}, ActivityBuildTest::K=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name="End.invalid_result", @options={}>}, ActivityBuildTest::L=>{Trailblazer::Circuit::Right=>#<Trailblazer::Circuit::End: @name=:success, @options={}>}, #<Trailblazer::Circuit::End: @name="End.invalid_result", @options={}>=>{}, #<Trailblazer::Circuit::End: @name=:success, @options={}>=>{}}}
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
    initial_plus_poles = Activity::Magnetic::PlusPoles.new.merge( Activity::Magnetic.Output(Circuit::Right, :success) => :success, Activity::Magnetic.Output(Circuit::Right, :failure) => :failure )

    seq = Activity::DSL.alter_sequence(
      G,
        id: :receive_process_id,
        strategy: ->(*args) { Activity::DSL::PoleGenerator::FastTrack.step(*args) },
        plus_poles: initial_plus_poles,
        sequence: Activity::Magnetic::Alterations.new,

        Activity::Magnetic.Output(Right, :success) => Circuit::End.new("End.invalid_result")#("End.invalid_result", :invalid_result)
     )

    pp seq
  end

end


