require "test_helper"

class TaskTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  class FIXMEHash # TODO: FIXME
    def initialize(hsh)
      @hash = hsh
    end

    def to_hash
      symbolized = @hash.inject({}) { |memo, (k,v)| memo[k.to_sym] = v; memo } # TODO: Trailblazer::Options::KW
    end

    def []=(k,v)
      @hash[k] = v
    end
  end

  module Blog
    Read    = ->(options, *)   { options["Read"] = 1; [ Circuit::Right, options ] }
    # Next    = ->(options, *arg) { options["NextPage"] = arg; [ options["return"], options ] }

    module_function
    def comment(options, *)
      options["Comment"] = 2; [ Circuit::Right, options ]
    end
  end

  class Blogger
    def rate(options, **)
      options["Rate"] = 3; [ Circuit::Right, options ]
    end
  end

  let (:circuit) do
    read    = Circuit::Task(instance: Blog::Read)
    comment = Circuit::Task(instance: Blog, method: :comment)
    rate    = Circuit::Task(instance: :context, method: :rate)

    circuit = Circuit::Activity("blog") do |evt|
      {
        evt[:Start] => { Circuit::Right => read },
        read        => { Circuit::Right => comment },
        comment     => { Circuit::Right => rate },
        rate        => { Circuit::Right => evt[:End] },
      }
    end
  end

  it do
    direction, result = circuit.(circuit[:Start], options=FIXMEHash.new({}), context: Blogger.new)

    direction.must_equal circuit[:End]
    options.must_equal({"Read"=>1, "Comment"=>2, "Rate"=>3})
  end

  it "executes without flow_options" do
    direction, result = circuit.(circuit[:Start], options=FIXMEHash.new({}))
  end
end
