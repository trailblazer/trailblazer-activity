require 'test_helper'

# TODO: 3-level nesting test.

class CircuitTest < Minitest::Spec
	Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(direction, options, *)   { options["Read"] = 1; [ Circuit::Right, options ] }
    Next    = ->(direction, options, *arg) { options["NextPage"] = []; [ options["return"], options ] }
    Comment = ->(direction, options, *)   { options["Comment"] = 2; [ Circuit::Right, options ] }
  end

  # let(:read)      { Circuit::Task(Blog::Read, "blog.read") }
  # let(:next_page) { Circuit::Task(Blog::NextPage, "blog.next") }
  # let(:comment)   { Circuit::Task(Blog::Comment, "blog.comment") }

  describe "plain circuit without any nesting" do
    let(:blog) do
      Circuit::Activity("blog.read/next") { |evt|
        {
          evt[:Start]  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => evt[:End], Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => evt[:End] }
        }
      }
    end

    it "ends before comment, on next_page" do
      blog.(blog[:Start], options = { "return" => Circuit::Right }).must_equal([blog[:End], {"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]}, {}])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]})
    end

    it "ends on comment" do
      blog.(blog[:Start], options = { "return" => Circuit::Left }).must_equal([blog[:End], {"return"=>Trailblazer::Circuit::Left, "Read"=>1, "NextPage"=>[], "Comment"=>2}, {}])

      options.must_equal({"return"=> Circuit::Left, "Read"=> 1, "NextPage"=>[], "Comment"=>2})
    end
  end

  describe "two End events" do
    Blog::Test = ->(direction, options, *) { [ options[:return], options ] }

    let(:flow) do
      Circuit::Activity(:reading, end: {default: Circuit::End.new(:default), retry: Circuit::End.new(:retry)} ) { |evt|
        {
          evt[:Start] => { Circuit::Right => Blog::Test },
          Blog::Test      => { Circuit::Right => evt[:End], Circuit::Left => evt[:End, :retry] }
        }
      }
    end

    it { flow.(flow[:Start], return: Circuit::Right).must_equal([flow[:End],         {:return=>Trailblazer::Circuit::Right}, {} ]) }
    it { flow.(flow[:Start], return: Circuit::Left ).must_equal([flow[:End, :retry], {:return=>Trailblazer::Circuit::Left}, {} ]) }
  end
end

class CircuitAlterTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  # A = ->(direction, options, *) { [ Circuit::Right, options ] }
  # B = ->(direction, options, *) { [ Circuit::Right, options ] }
  class A
  end
  class C
  end
  class B
  end

  let(:circuit) do
    Circuit::Activity(id: "A/") { |evt|
      {
        evt[:Start] => { Circuit::Right => A },
        A           => { Circuit::Right => B },
        B           => { Circuit::Right => evt[:End] }
      }
    }.to_circuit
  end

  it { circuit.must_inspect "{#<Start: default {}>=>{Right=>CircuitAlterTest::A}, CircuitAlterTest::A=>{Right=>CircuitAlterTest::B}, CircuitAlterTest::B=>{Right=>#<End: default {}>}}" }
  it { Circuit::Alter(circuit, :append, C).must_inspect "{#<Start: default {}>=>{Right=>CircuitAlterTest::A}, CircuitAlterTest::A=>{Right=>CircuitAlterTest::B}, CircuitAlterTest::B=>{Right=>CircuitAlterTest::C}, CircuitAlterTest::C=>{Right=>#<End: default {}>}}" }
end

module MiniTest::Assertions
  def assert_inspect(text, subject)
    map, _ = subject.to_fields
    map.inspect.gsub(/0x.+?lambda\)/, "").gsub("Trailblazer::Circuit::", "").must_equal(text)
  end
end
Trailblazer::Circuit.infect_an_assertion :assert_inspect, :must_inspect

# decouple circuit and implementation
# visible structuring of flow
