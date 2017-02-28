require "test_helper"

class NestedHelper < Minitest::Spec
Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(direction, options, *)    { options["Read"] = 1; [ Circuit::Right, options ] }
    Next    = ->(direction, options, *arg) { options["NextPage"] = arg; [ options["return"], options ] }
    Comment = ->(direction, options, *)    { options["Comment"] = 2; [ Circuit::Right, options ] }
  end

  module User
    Relax   = ->(direction, options) { options["Relax"]=true; [ Circuit::Right, options ] }
  end

  describe "plain circuit without any nesting" do
    let(:blog) do
      Circuit.new("blog.read/next") { |evt|
        {
          evt.Start  => { Circuit::Right => Blog::Read },
          Blog::Read => { Circuit::Right => Blog::Next },
          Blog::Next => { Circuit::Right => evt.End, Circuit::Left => Blog::Comment },
          Blog::Comment => { Circuit::Right => evt.End }
        }
      }
    end

    let(:user) do
      Circuit.new("user.blog") { |user|
        {
          user.Start => { Circuit::Right => nested=Circuit::Nested(blog) },
          nested     => { blog.End => User::Relax },

          User::Relax => { Circuit::Right => user.End }
        }
      }
    end

    it "ends before comment, on next_page" do
      user.(Circuit.START, options = { "return" => Circuit::Right }).must_equal([user.End, {"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true}])

      options.must_equal({"return"=>Trailblazer::Circuit::Right, "Read"=>1, "NextPage"=>[], "Relax"=>true})
    end
  end
end
