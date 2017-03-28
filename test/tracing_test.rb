require "test_helper"
require "trailblazer/circuit/trace"
require "trailblazer/circuit/presenter"

class TracingTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  module Blog
    Read    = ->(options, *) { options[:read] = 1;  [ Circuit::Right, options ] }
    # Nest    = ->(options, *) { options["Nest"] = 2; Nested.(Circuit::Start, options) [ Circuit::Right, options ] }
    Write   = ->(options, *) { options[:write] = 3; [ Circuit::Right, options ] }
  end

    # Nested  = ->(options, *) { snippet }

  let (:circuit) do
    read    = Circuit::Task(instance: Blog::Read)
    write   = Circuit::Task(instance: Blog::Write)
    _nest   = Circuit::Nested(circuit2)

    circuit = Circuit::Activity(id: "blog", read=>["Blog::Read"], write=>["Blog::Write"], _nest=> ["[circuit2]", true]) do |evt|
      {
        evt[:Start] => { Circuit::Right => read },
        read        => { Circuit::Right => _nest },
        _nest       => { circuit2[:End] => write },
        write       => { Circuit::Right => evt[:End] },
      }
    end
  end

  module User
    Talk    = ->(options, *) { options[:talk] = 1;  [ Circuit::Right, options ] }
    Speak   = ->(options, *) { options[:speak] = 3; [ Circuit::Right, options ] }
  end

  let (:circuit2) do
    talk    = Circuit::Task(instance: User::Talk)
    speak   = Circuit::Task(instance: User::Speak)

    circuit = Circuit::Activity({ id: "user", talk => ["User::Talk"], speak => ["User::Speak"] }) do |evt|
      {
        evt[:Start] => { Circuit::Right => talk },
        talk        => { Circuit::Right => speak },
        speak       => { Circuit::Right => evt[:End] },
      }
    end
  end

  it do
    direction, result = circuit.(circuit[:Start], options={}, runner: runner=Circuit::Trace.new, stack: stack=[])

    direction.must_equal circuit[:End]
    options.must_equal({:read=>1, :talk=>1, :speak=>3, :write=>3})

    Circuit::Presenter.new.tree(stack)

    stack.collect{ |ary| ary[0] }.must_equal [circuit[:Start], "Blog::Read", "[circuit2]", "Blog::Write", circuit[:End]]
    stack[2][5].collect{ |ary| ary[0] }.must_equal [circuit2[:Start], "User::Talk", "User::Speak", circuit2[:End]]
  end
end

