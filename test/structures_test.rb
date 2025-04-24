require "test_helper"

class StructuresTest < Minitest::Spec
  describe "End(semantic)" do
    let(:evt) { Trailblazer::Activity::End(:meaning) }

    it "#call always returns the End instance itself" do
      signal, (_ctx, _flow_options) = evt.([{a: 1}, {}])

      assert_equal signal, evt
    end

    it "responds to #to_h" do
      assert_equal evt.to_h, {semantic: :meaning}
    end

    it "has strict object identity" do
      refute_equal evt, Trailblazer::Activity::End(:meaning)
    end

    it "responds to #inspect" do
      assert_equal evt.inspect, %(#<Trailblazer::Activity::End semantic=:meaning>)
    end

    it "allows more variables" do
      assert_equal Trailblazer::Activity::End.new(semantic: :success, type: :event).to_h, { semantic: :success, type: :event }
    end
  end
end
