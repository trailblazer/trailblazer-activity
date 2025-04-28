require "pp"
require "trailblazer-activity"
require "minitest/autorun"

Minitest::Spec.class_eval do
  def assert_equal(asserted, expected, *args)
    super(expected, asserted, *args)
  end

  require "trailblazer/activity/testing"
  include Trailblazer::Activity::Testing::Assertions

  module Minitest::Spec::Implementing
    extend Trailblazer::Activity::Testing.def_tasks(:a, :b, :c, :d, :f, :g)

    Start = Trailblazer::Activity::Start.new(semantic: :default)
    Failure = Trailblazer::Activity::End(:failure)
    Success = Trailblazer::Activity::End(:success)
  end
end

T = Trailblazer::Activity::Testing

module Fixtures
  # TODO: test this.
  def self.default_tasks(_old_ruby_kws = {}, **tasks)
    tasks = tasks.merge(_old_ruby_kws)

    {
      "Start.default" => Trailblazer::Activity::Start.new(semantic: :default),
      # tasks
      "b" => Minitest::Spec::Implementing.method(:b),
      "c" => Minitest::Spec::Implementing.method(:c),
      "End.failure" => Trailblazer::Activity::End(:failure),
      "End.success" => Trailblazer::Activity::End(:success),
    }.merge(**tasks)
  end

  # TODO: test this.
  def self.default_wiring(tasks, _old_ruby_kws = {}, **connections)
    start, b, c, failure, success = tasks.values

    {
      start   => {Trailblazer::Activity::Right => b},
      b       => {Trailblazer::Activity::Right => c, Trailblazer::Activity::Left => failure},
      c       => {Trailblazer::Activity::Right => success},
      **connections
    }
  end

  def self.flat_activity(wiring: nil, tasks: self.default_tasks, config: {})
    start, b, c, failure, success = tasks.values

    wiring ||= Fixtures.default_wiring(tasks)

    # standard outputs, for introspection interface.
    right_output = Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)
    left_output = Trailblazer::Activity::Output(Trailblazer::Activity::Left, :failure)

    # FIXME: allow  overriding this.
    nodes_attributes = [
      # id, task, data, [outputs]
      ["Start.default", start, {}, [right_output]],
      ["b", b, {}, [right_output, left_output]],
      ["c", c, {}, [right_output]],
      ["End.failure", failure, {stop_event: true}, []],
      ["End.success", success, {stop_event: true}, []],
    ]

    circuit = Trailblazer::Activity::Circuit.new(
      wiring,
      [failure, success], # termini
      start_task: start
    )

    activity_outputs = [
      Trailblazer::Activity::Output(failure, :failure),
      Trailblazer::Activity::Output(success, :success)
    ]


    # add :wrap_static here.
    # config = {
    # }

    schema = Trailblazer::Activity::Schema.new(
      circuit,
      activity_outputs,
      Trailblazer::Activity::Schema::Nodes(nodes_attributes),
      config
    )

    Trailblazer::Activity.new(schema)
  end
end


Minitest::Spec.class_eval do
  require "trailblazer/core"
  CU = Trailblazer::Core::Utils
end
