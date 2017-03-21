require "test_helper"

class TieTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(direction, options, *)   { options["Read"] = 1; [ Circuit::Right, options ] }
    Next    = ->(direction, options, *arg) { options["NextPage"] = arg; [ options["return"], options ] }
    Comment = ->(direction, options, *)   { options["Comment"] = 2; [ Circuit::Right, options ] }
  end

  it do
    read    = Circuit::Task(Blog::Read)
    comment = Circuit::Task(Blog::Comment)

    circuit = Circuit::Activity("blog") do |evt|
      {
        evt[:Start] => { Circuit::Right => read },
        read        => { Circuit::Right => comment },
        comment     => { Circuit::Right => evt[:End] },
      }
    end

    direction, result = circuit.(circuit[:Start], options={})

    direction.must_equal circuit[:End]
    options.must_equal({"Read"=>1, "Comment"=>2})
  end
end
