require "test_helper"

class StructuresTest < Minitest::Spec
  describe "End(semantic)" do
    let(:evt) { Activity::End(:meaning) }

    it "#call always returns the End instance itself" do
      signal, (ctx, flow_options) = evt.( [{ a: 1 }, {}], {} )

      signal.must_equal evt
    end

    it "responds to #to_h" do
      evt.to_h.must_equal( { semantic: :meaning } )
    end

    it "has strict object identity" do
      evt.wont_equal Activity::End(:meaning)
    end

    it "responds to #inspect" do
      evt.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:meaning>}
    end

    it "allows more variables" do
      Activity::End.new(semantic: :success, type: :event).to_h.must_equal(semantic: :success, type: :event)
    end
  end
end
