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

    circuit = Circuit::Activity("blog") do |evt|
      {
        evt[:Start] => { Circuit::Right => read },
        read        => { Circuit::Right => _nest = Circuit::Nested(circuit2) },
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

    circuit = Circuit::Activity("user") do |evt|
      {
        evt[:Start] => { Circuit::Right => talk },
        talk        => { Circuit::Right => speak },
        speak       => { Circuit::Right => evt[:End] },
      }
    end
  end

  it do
    direction, result = circuit.(circuit[:Start], options={}, runner: runner=Circuit::Trace.new)

    direction.must_equal circuit[:End]
    options.must_equal({:read=>1, :talk=>1, :speak=>3, :write=>3})

    require "pp"
    pp runner.to_stack
  end
end

module Trailblazer
  class Circuit
    class Trace
      def initialize
        @stack = []
      end

      def call(activity, direction, args, flow_options)
        Run.(activity, direction, args, flow_options).tap do |direction, options|
          @stack << [activity, direction, options.dup]
          # puts "@@@@@ tracing=========> #{res.inspect}"
        end
      end

      def to_stack
        @stack
      end
    end
  end
end
