require "test_helper"

class WipCallTest < Minitest::Spec
  # * We want Circuit because it's good to have a clean, small runtime structure
  # * {Activity} maintains circuit, nodes/debugging, outputs for modelling. {:wrap_static}
  #              this is what we want to place as a circuit step when nesting.

  class Activity
    # We explicitly do *not* have a #call method.

    def to_h
      {
        circuit: @circuit
      }
    end
  end

  it "what" do

  end
end
