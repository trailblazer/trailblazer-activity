require "test_helper"

class TaskTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(options, *)   { options[:Read] = 1; [ Circuit::Right, options ] }

    module_function
    def comment(options, *)
      options[:Comment] = 2; [ Circuit::Right, options ]
    end
  end

  class Blogger
    def rate(options, **)
      options[:Rate] = 3; [ Circuit::Right, options ]
    end
  end

  let (:circuit) do
    read    = Circuit::Task::Binary( ->(direction, options, flow_options) { Trailblazer::Option::KW(Blog::Read).(options, flow_options) } )
    comment = Circuit::Task::Binary( ->(direction, options, flow_options) { Trailblazer::Option::KW(Blog.method(:comment)).(options, flow_options) } )
    rate    = Circuit::Task::Binary( ->(direction, options, flow_options) { Trailblazer::Option::KW(:rate).(options, flow_options) } )

    circuit = Circuit::Activity(id: "blog") do |evt|
      {
        evt[:Start] => { Circuit::Right => read },
        read        => { Circuit::Right => comment },
        comment     => { Circuit::Right => rate },
        rate        => { Circuit::Right => evt[:End] },
      }
    end
  end

  it do
    direction, result = circuit.(circuit[:Start], options={}, exec_context: Blogger.new)

    direction.must_equal circuit[:End]
    options.must_equal({:Read=>1, :Comment=>2, :Rate=>3})
  end

  it "executes without flow_options" do
    skip
    direction, result = circuit.(circuit[:Start], options={})
  end
end
