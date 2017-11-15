require "test_helper"

class RailwayTest < Minitest::Spec
  class A; end

  # outputs for task.
  let(:initial_plus_poles) { Activity::Magnetic::DSL::PlusPoles.new.merge( Activity::Magnetic.Output(Circuit::Right, :success) => :success, Activity::Magnetic.Output(Circuit::Right, :failure) => :failure ) }

  it do
    magnetic_to, plus_poles = Activity::Magnetic::DSL::Railway.step( A, plus_poles: initial_plus_poles )

    magnetic_to.must_equal [:success]
    Inspect(plus_poles.to_a).must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:failure>, color=:failure>]}
  end

  it do
    magnetic_to, plus_poles = Activity::Magnetic::DSL::Railway.fail( A, plus_poles: initial_plus_poles )

    magnetic_to.must_equal [:failure]
    Inspect(plus_poles.to_a).must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:failure>, color=:failure>]}
  end

  it do
    magnetic_to, plus_poles = Activity::Magnetic::DSL::FastTrack.step( A, plus_poles: initial_plus_poles, fast_track: true )

    magnetic_to.must_equal [:success]
    Inspect(plus_poles.to_a).must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=:success>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:failure>, color=:failure>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::DSL::FastTrack::FailFast, semantic=:fail_fast>, color=:fail_fast>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::DSL::FastTrack::PassFast, semantic=:pass_fast>, color=:pass_fast>]}
  end

  # with different colors, we get different paths.
  it do
    magnetic_to, plus_poles = Activity::Magnetic::DSL::FastTrack.step( A, plus_poles: initial_plus_poles, fast_track: true, track_color: ":success-again", failure_color: "failure-0" )

    magnetic_to.must_equal [":success-again"]
    Inspect(plus_poles.to_a).must_equal %{[#<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, color=":success-again">, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:failure>, color="failure-0">, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::DSL::FastTrack::FailFast, semantic=:fail_fast>, color=:fail_fast>, #<struct Trailblazer::Activity::Magnetic::PlusPole output=#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Activity::Magnetic::DSL::FastTrack::PassFast, semantic=:pass_fast>, color=:pass_fast>]}
  end
end
