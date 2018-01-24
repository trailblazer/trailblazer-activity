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
  end
end
