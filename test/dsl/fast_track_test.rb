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


  it "allows to define custom End instance" do
    class MyFail; end
    class MySuccess; end
    class MyPassFast; end
    class MyFailFast; end

    process, _ = Builder::FastTrack.build track_end: MySuccess, failure_end: MyFail, pass_fast_end: MyPassFast, fail_fast_end: MyFailFast do
      step :a, {}
    end

    # seq = Finalizer.adds_to_tripletts(adds)

    Cct( process ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => :a
:a
 {Trailblazer::Activity::Right} => DSLFastTrackTest::MySuccess
 {Trailblazer::Activity::Left} => DSLFastTrackTest::MyFail
DSLFastTrackTest::MySuccess

DSLFastTrackTest::MyFail

DSLFastTrackTest::MyPassFast

DSLFastTrackTest::MyFailFast
}
  end

  it "allows to provide :plus_poles and customize their connections" do
    initial_plus_poles = Activity::Magnetic::DSL::PlusPoles.new.merge(
      Activity.Output(Activity::Right, :success) => :success,
      Activity.Output("Signal A", :exception)  => :exception,
      Activity.Output(Activity::Left, :failure) => :failure
    )


    adds = Builder::FastTrack.plan do
      step G,
        id: :receive_process_id,
        plus_poles: initial_plus_poles,

        # existing success to new end
        Activity.Output(Right, :success)        => Activity.End(:invalid_result),
        Activity.Output("Signal A", :exception) => Activity.End(:signal_a_reached)
    end

    seq = Finalizer.adds_to_tripletts(adds)

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLFastTrackTest::G
 (success)/Right ==> "receive_process_id-Trailblazer::Activity::Right"
 (exception)/Signal A ==> "receive_process_id-Signal A"
 (failure)/Left ==> :failure
[:success] ==> #<End:success/:success>
 []
[:failure] ==> #<End:failure/:failure>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
["receive_process_id-Trailblazer::Activity::Right"] ==> #<End:invalid_result/:invalid_result>
 []
["receive_process_id-Signal A"] ==> #<End:signal_a_reached/:signal_a_reached>
 []
}
  end

  it "accepts :before and :group" do
    adds = Builder::FastTrack.plan do
      step J, id: "report_invalid_result"
      step K, id: "log_invalid_result", before: "report_invalid_result"
      step I, id: "start/I", group: :start
    end

    seq = Finalizer.adds_to_tripletts(adds)

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> DSLFastTrackTest::I
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> DSLFastTrackTest::K
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> DSLFastTrackTest::J
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> #<End:success/:success>
 []
[:failure] ==> #<End:failure/:failure>
 []
[:pass_fast] ==> #<End:pass_fast/:pass_fast>
 []
[:fail_fast] ==> #<End:fail_fast/:fail_fast>
 []
}
  end
end
