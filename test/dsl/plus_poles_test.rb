require "test_helper"

class PlusPolesTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right

  it do
    poles = Trailblazer::Activity::Magnetic::DSL::PlusPoles.new

    new_poles = poles.merge( Activity::Magnetic.Output(Right, :success) => :success, Activity::Magnetic.Output(Left, :failure) => :failure )

    new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:failure>]}

    # overwrites the old :success Output
    overwritten = new_poles.merge( Activity::Magnetic.Output("Right", :success) => :failure )
    overwritten.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=\"Right\", semantic=:success>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:failure>]}


    # add new output
    new_poles = new_poles.merge( Activity::Magnetic.Output("Another", :exception) => :fail_fast )

    new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=\"Another\", semantic=:exception>, color=:fail_fast>]}
  end

  # overwrite existing
  it do
    poles = Trailblazer::Activity::Magnetic::DSL::PlusPoles.new

    new_poles = poles.merge( Activity::Magnetic.Output(Right, :success) => :success, Activity::Magnetic.Output(Left, :failure) => :failure )

    # reconnect
    new_poles = new_poles.reconnect(:success => :red)

    new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:red>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:failure>]}

    # reconnect with multiple keys
    new_poles = new_poles.reconnect(:success => :green, :failure => :greenish)

    new_poles.to_a.inspect.must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:green>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, color=:greenish>]}
  end

  describe "::from_outputs" do
    it do
      activity = Activity.build do
        task :a
      end

      Activity::Magnetic::DSL::PlusPoles::from_outputs( activity.outputs ).to_a.inspect.gsub(/0x\w+/, "").inspect.
        must_equal %{"[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=#<Trailblazer::Circuit::End: @name=:success, @options={:semantic=>:success}>, semantic=:success>, color=:success>]"}
    end
  end
end
