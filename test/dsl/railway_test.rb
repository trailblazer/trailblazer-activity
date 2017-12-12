require "test_helper"

class RailwayTest < Minitest::Spec
  Left = Trailblazer::Activity::Left
  Right = Trailblazer::Activity::Right

  class A; end
  class B; end
  class C; end
  class D; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  Builder   = Activity::Magnetic::Builder
  Finalizer = Activity::Magnetic::Builder::Finalizer

  describe "Activity::Railway" do
    it "move me" do
      activity = Activity::Railway.build do
        step J
        step K
      end

      Trailblazer::Activity::Introspect.Cct( activity.instance_variable_get(:@process) ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => RailwayTest::J
RailwayTest::J
 {Trailblazer::Activity::Right} => RailwayTest::K
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
RailwayTest::K
 {Trailblazer::Activity::Right} => #<End:success/:success>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
#<End:success/:success>

#<End:failure/:failure>
}
    end
  end

  it "builds tripletts for Railway pattern" do
    adds = Builder::Railway.plan do
      step J
      step K
    end

    seq = Finalizer.adds_to_tripletts(adds)

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> RailwayTest::J
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> RailwayTest::K
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> #<End:success/:success>
 []
[:failure] ==> #<End:failure/:failure>
 []
}
  end

  it "standard path ends in End.success/:success" do
    adds = Builder::Railway.plan do
      step J, id: "report_invalid_result"
      step K, id: "log_invalid_result"
      fail B, id: "b"
      pass C, id: "c"
      fail D, id: "d"
    end

    seq = Finalizer.adds_to_tripletts(adds)

    Seq(seq).must_equal %{
[] ==> #<Start:default/nil>
 (success)/Right ==> :success
[:success] ==> RailwayTest::J
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:success] ==> RailwayTest::K
 (success)/Right ==> :success
 (failure)/Left ==> :failure
[:failure] ==> RailwayTest::B
 (success)/Right ==> :failure
 (failure)/Left ==> :failure
[:success] ==> RailwayTest::C
 (success)/Right ==> :success
 (failure)/Left ==> :success
[:failure] ==> RailwayTest::D
 (success)/Right ==> :failure
 (failure)/Left ==> :failure
[:success] ==> #<End:success/:success>
 []
[:failure] ==> #<End:failure/:failure>
 []
}

    process, _ = Finalizer.( adds )
Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => RailwayTest::J
RailwayTest::J
 {Trailblazer::Activity::Right} => RailwayTest::K
 {Trailblazer::Activity::Left} => RailwayTest::B
RailwayTest::K
 {Trailblazer::Activity::Left} => RailwayTest::B
 {Trailblazer::Activity::Right} => RailwayTest::C
RailwayTest::B
 {Trailblazer::Activity::Right} => RailwayTest::D
 {Trailblazer::Activity::Left} => RailwayTest::D
RailwayTest::C
 {Trailblazer::Activity::Right} => #<End:success/:success>
 {Trailblazer::Activity::Left} => #<End:success/:success>
RailwayTest::D
 {Trailblazer::Activity::Right} => #<End:failure/:failure>
 {Trailblazer::Activity::Left} => #<End:failure/:failure>
#<End:success/:success>

#<End:failure/:failure>
}
    Ends(process).must_equal %{[#<End:success/:success>,#<End:failure/:failure>]}
  end

  it "allows to define custom End instance" do
    class MyFail; end
    class MySuccess; end

    adds = Builder::Railway.plan( track_end: MySuccess, failure_end: MyFail ) do
      step :a, {}
    end

    process, _ = Finalizer.(adds)

    puts Cct(process)
    Cct( process ).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => :a
:a
 {Trailblazer::Activity::Right} => RailwayTest::MySuccess
 {Trailblazer::Activity::Left} => RailwayTest::MyFail
RailwayTest::MySuccess

RailwayTest::MyFail
}
  end
end
