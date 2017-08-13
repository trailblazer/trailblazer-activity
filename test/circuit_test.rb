require 'test_helper'

# TODO: 3-level nesting test.

class CircuitTest < Minitest::Spec
	Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(direction, options, *args)   { options["Read"] = 1; [ Circuit::Right, options, args ] }
    Next    = ->(direction, options, *args) { options["NextPage"] = []; [ options["return"], options, args ] }
    Comment = ->(direction, options, *args)   { options["Comment"] = 2; [ Circuit::Right, options, args ] }
  end

  # let(:read)      { Circuit::Task(Blog::Read, "blog.read") }
  # let(:next_page) { Circuit::Task(Blog::NextPage, "blog.next") }
  # let(:comment)   { Circuit::Task(Blog::Comment, "blog.comment") }

  describe "plain circuit without any nesting" do
    let(:blog) do
      Circuit::Activity(id: "blog.read/next") { |evt|
        {
          evt[:Start]  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => evt[:End], Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => evt[:End] }
        }
      }
    end

    it "ends before comment, on next_page" do
      direction, _options = blog.(blog[:Start], options = { "return" => Circuit::Right })
      [direction, _options].must_equal([blog[:End], {"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]}])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[]})
    end

    it "ends on comment" do
      direction, _options = blog.(blog[:Start], options = { "return" => Circuit::Left })
      [direction, _options].must_equal([blog[:End], {"return"=>Trailblazer::Circuit::Left, "Read"=>1, "NextPage"=>[], "Comment"=>2}])

      options.must_equal({"return"=> Circuit::Left, "Read"=> 1, "NextPage"=>[], "Comment"=>2})
    end
  end

  #- Circuit::End()
  describe "two End events" do
    Blog::Test = ->(direction, options, *) { [ options[:return], options ] }

    let(:flow) do
      Circuit::Activity({ id: :reading }, end: {default: Circuit::End(:default), retry: Circuit::End(:retry)} ) { |evt|
        {
          evt[:Start] => { Circuit::Right => Blog::Test },
          Blog::Test      => { Circuit::Right => evt[:End], Circuit::Left => evt[:End, :retry] }
        }
      }
    end

    it { flow.(flow[:Start], return: Circuit::Right)[0..1].must_equal([flow[:End],         {:return=>Trailblazer::Circuit::Right} ]) }
    it { flow.(flow[:Start], return: Circuit::Left )[0..1].must_equal([flow[:End, :retry], {:return=>Trailblazer::Circuit::Left} ]) }
  end

  describe "arbitrary args for Circuit#call are passed and returned" do
    Plus    = ->(direction, options, flow_options, a, b)      { [ direction, options, flow_options, a + b, 1 ] }
    PlusOne = ->(direction, options, flow_options, ab_sum, i) { [ direction, options, flow_options, ab_sum.to_s, i+1 ] }

    let(:flow) do
      Circuit::Activity({ id: :reading }, end: {default: Circuit::End(:default)} ) { |evt|
        {
          evt[:Start] => { Circuit::Right => Plus },
          Plus        => { Circuit::Right => PlusOne },
          PlusOne     => { Circuit::Right => evt[:End] },
        }
      }
    end

    it { flow.( flow[:Start], {}, {a:"B"}, 1, 2 ).must_equal [ flow[:End], {}, {a:"B"}, "3", 2 ] }
  end
end

# decouple circuit and implementation
# visible structuring of flow
