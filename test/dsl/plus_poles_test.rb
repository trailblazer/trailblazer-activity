require "test_helper"

class PlusPolesTest < Minitest::Spec
  Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right

  it do
    poles = Trailblazer::Activity::Magnetic::PlusPoles.new

    new_poles = poles.merge( Activity::Magnetic.Output(Right, :success) => :success, Activity::Magnetic.Output(Left, :failure) => :failure )

    new_poles.to_h.inspect.must_equal %{{:success=>[#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, :success], :failure=>[#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, :failure]}}

    # overwrites the old :success Output
    overwritten = new_poles.merge( Activity::Magnetic.Output("Right", :success) => :failure )
    overwritten.to_h.inspect.must_equal %{{:success=>[#<struct Trailblazer::Activity::Magnetic::Output signal="Right", semantic=:success>, :failure], :failure=>[#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, :failure]}}


    # add new output
    new_poles = new_poles.merge( Activity::Magnetic.Output("Another", :exception) => :fail_fast )

    new_poles.to_h.inspect.must_equal %{{:success=>[#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, :success], :failure=>[#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, :failure], :exception=>[#<struct Trailblazer::Activity::Magnetic::Output signal=\"Another\", semantic=:exception>, :fail_fast]}}
  end

  # overwrite existing
  it do
    poles = Trailblazer::Activity::Magnetic::PlusPoles.new

    new_poles = poles.merge( Activity::Magnetic.Output(Right, :success) => :success, Activity::Magnetic.Output(Left, :failure) => :failure )

    # reconnect
    new_poles = new_poles.reconnect(:success, :red)

    new_poles.to_h.inspect.must_equal %{{:success=>[#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Right, semantic=:success>, :red], :failure=>[#<struct Trailblazer::Activity::Magnetic::Output signal=Trailblazer::Circuit::Left, semantic=:failure>, :failure]}}
  end
end
