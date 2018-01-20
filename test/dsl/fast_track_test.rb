require "test_helper"

class DSLFastTrackTest < Minitest::Spec

  describe ":magnetic_to" do
    it "overrides default @track_color" do

skip "we should test that low level somewhere"

      adds = Builder::FastTrack.plan do
        step G, magnetic_to: []
        pass I, magnetic_to: [:pass_me_a_beer]
        fail J, magnetic_to: []
      end

      seq = Finalizer.adds_to_tripletts(adds)

      assert_main seq, %{
[] ==> DSLFastTrackTest::G
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:pass_me_a_beer] ==> DSLFastTrackTest::I
 (success)/Right ==> :success
 (failure)/Left ==> :success
[] ==> DSLFastTrackTest::J
 (success)/Right ==> :failure
 (failure)/Left ==> :failure
}
    end
  end



end
