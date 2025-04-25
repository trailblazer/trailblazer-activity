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
  module FlatActivity
    def tasks
      @tasks ||= [
        start = Trailblazer::Activity::Start.new(semantic: :default),
        # tasks
        b = Minitest::Spec::Implementing.method(:b),
        c = Minitest::Spec::Implementing.method(:c),
        failure = Trailblazer::Activity::End(:failure),
        success = Trailblazer::Activity::End(:success),
      ]
    end

    def flat_activity(wiring: nil, tasks: self.tasks, config: {})
      return @_flat_activity if @_flat_activity

      start, b, c, failure, success = tasks

      wiring ||= {
        start   => {Trailblazer::Activity::Right => b},
        b       => {Trailblazer::Activity::Right => c, Trailblazer::Activity::Left => failure},
        c       => {Trailblazer::Activity::Right => success},
      }

      # standard outputs, for introspection interface.
      right_output = Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)
      left_output = Trailblazer::Activity::Output(Trailblazer::Activity::Left, :failure)

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

      @_flat_activity = Trailblazer::Activity.new(schema)
    end
  end

  module NestingActivity
    def tasks(flat_activity:)
      @tasks ||= [
        start = Trailblazer::Activity::Start.new(semantic: :default),
        # tasks
        a = Minitest::Spec::Implementing.method(:a),
        flat_activity,
        # c = Minitest::Spec::Implementing.method(:c),
        failure = Trailblazer::Activity::End(:failure),
        success = Trailblazer::Activity::End(:success),
      ]
    end

    def activity(wiring: nil, tasks: self.tasks, config: {})
      return @_nesting_activity if @_nesting_activity

      start, a, flat_activity, failure, success = tasks

      flat_activity_failure_output, flat_activity_success_output = flat_activity.to_h[:outputs]

      wiring ||= {
        start         => {Trailblazer::Activity::Right => a},
        a             => {Trailblazer::Activity::Right => flat_activity, Trailblazer::Activity::Left => failure},
        flat_activity => {flat_activity_success_output.signal => success, flat_activity_failure_output.signal => failure},
      }

      # standard outputs, for introspection interface.
      right_output = Trailblazer::Activity::Output(Trailblazer::Activity::Right, :success)
      left_output = Trailblazer::Activity::Output(Trailblazer::Activity::Left, :failure)

      nodes_attributes = [
        # # id, task, data, [outputs]
        ["Start.default", start, {}, [right_output]],
        ["a", a, {}, [right_output]],
        ["flat_activity", flat_activity, {}, [right_output, left_output]],
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

      schema = Trailblazer::Activity::Schema.new(
        circuit,
        activity_outputs,
        Trailblazer::Activity::Schema::Nodes(nodes_attributes),
        config
      )

      @_nesting_activity = Trailblazer::Activity.new(schema)
    end
  end
end


Minitest::Spec.class_eval do
  include Fixtures::FlatActivity
  # include Fixtures::NestingActivity


  require "trailblazer/core"
  CU = Trailblazer::Core::Utils
end
