require "test_helper"

class ActivityTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  module Blog
    Read     = ->(options) { options["Read"] = Trailblazer::Circuit::Right }
    NextPage = ->(options) { options["NextPage"] = Trailblazer::Circuit::Right }
    Comment  = ->(options) { options["Comment"] = Trailblazer::Circuit::Right }
  end

  let (:step)     { ->(*) { snippet } }
  let (:activity) { Circuit::Activity(step, start: { default: "START" }, end: { stop: "END" }) {} }

  # it { activity.circuit.must_equal step }
  # errors: unknown fields
  it { assert_raises { activity[:__not_existing] } }
  it { assert_raises { activity[:Start, :__not_existing] } }
  # start
  it { activity[:Start].must_equal "START" }
  it { activity[:Start, :default].must_equal "START" }
  # end
  it { activity[:End, :stop].must_equal "END" }
end
