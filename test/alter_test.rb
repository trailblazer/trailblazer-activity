require "test_helper"

class AlterTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  class A
  end
  class C
  end
  class B
  end

  let(:activity) do
    Circuit::Activity(id: "A/") { |evt|
      {
        evt[:Start] => { Circuit::Right => A },
        A           => { Circuit::Right => B },
        B           => { Circuit::Right => evt[:End] }
      }
    }
  end

  it { activity.must_inspect "{#<Start: default {}>=>{Right=>A}, A=>{Right=>B}, B=>{Right=>#<End: default {}>}}" }
  it { Circuit::Activity::Alter(activity, :append, C).must_inspect "{#<Start: default {}>=>{Right=>A}, A=>{Right=>B}, B=>{Right=>C}, C=>{Right=>#<End: default {}>}}" }
end

module MiniTest::Assertions
  def assert_inspect(text, subject)
    circuit, _ = subject.values
    map, _ = circuit.to_fields
    map.inspect.gsub(/0x.+?lambda\)/, "").gsub("Trailblazer::Circuit::", "").gsub("AlterTest::", "").must_equal(text)
  end
end
Trailblazer::Circuit::Activity.infect_an_assertion :assert_inspect, :must_inspect
