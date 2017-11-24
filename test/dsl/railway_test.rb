require "test_helper"

class RailwayTest < Minitest::Spec
    Left = Trailblazer::Circuit::Left
  Right = Trailblazer::Circuit::Right

  class A; end
  class B; end
  class C; end
  class D; end
  class G; end
  class I; end
  class J; end
  class K; end
  class L; end

  Builder = Activity::Magnetic::Builder::Railway

  it "standard path ends in End.success/:success" do
    seq, adds = Builder.draft do
      step J, id: "report_invalid_result"
      step K, id: "log_invalid_result"
      fail B, id: "b"
      pass C, id: "c"
      fail D, id: "d"
    end

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

    process, _ = Builder.finalize( adds )
Cct(process).must_equal %{
#<Start:default/nil>
 {Trailblazer::Circuit::Right} => RailwayTest::J
RailwayTest::J
 {Trailblazer::Circuit::Right} => RailwayTest::K
 {Trailblazer::Circuit::Left} => RailwayTest::B
RailwayTest::K
 {Trailblazer::Circuit::Left} => RailwayTest::B
 {Trailblazer::Circuit::Right} => RailwayTest::C
RailwayTest::B
 {Trailblazer::Circuit::Right} => RailwayTest::D
 {Trailblazer::Circuit::Left} => RailwayTest::D
RailwayTest::C
 {Trailblazer::Circuit::Right} => #<End:success/:success>
 {Trailblazer::Circuit::Left} => #<End:success/:success>
RailwayTest::D
 {Trailblazer::Circuit::Right} => #<End:failure/:failure>
 {Trailblazer::Circuit::Left} => #<End:failure/:failure>
#<End:success/:success>

#<End:failure/:failure>
}
    Ends(process).must_equal %{[#<End:success/:success>,#<End:failure/:failure>]}
  end
end
