require "test_helper"

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

    require "pp"
    pp stack
  end
end

module Trailblazer
  class Circuit
    class Trace
      def initialize
        @stack = []
      end

      def call(activity, direction, args, circuit:, stack:, **flow_options)
        activity_name, is_nested = circuit.instance_variable_get(:@name)[activity]
        activity_name ||= activity

        Run.(activity, direction, args, stack: is_nested ? [] : stack, **flow_options).tap do |direction, outgoing_options, **flow_options|
          stack << [activity_name, activity, direction, outgoing_options.dup, is_nested ? flow_options[:stack] : nil ]
        end
      end
    end
  end
end
