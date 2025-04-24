require "pp"
require "trailblazer-activity"
require "minitest/autorun"

Minitest::Spec.class_eval do
  def assert_equal(asserted, expected, *args)
    super(expected, asserted, *args)
  end

  require "trailblazer/activity/testing"
  include Trailblazer::Activity::Testing::Assertions
end

T = Trailblazer::Activity::Testing

require "fixtures"
Minitest::Spec::Activity = Trailblazer::Activity
Minitest::Spec::Implementing = Fixtures::Implementing

module Fixtures
  module FlatActivity
    def tasks
      @tasks ||= [
        start = Activity::Start.new(semantic: :default),
        # tasks
        b = Implementing.method(:b),
        c = Implementing.method(:c),
        failure = Activity::End(:failure),
        success = Activity::End(:success),
      ]
    end

    def flat_activity(wiring: nil, tasks: self.tasks, config: {})
      return @_flat_activity if @_flat_activity

      start, b, c, failure, success = tasks

      wiring ||= {
        start   => {Activity::Right => b},
        b       => {Activity::Right => c, Activity::Left => failure},
        c       => {Activity::Right => success},
      }

      # standard outputs, for introspection interface.
      right_output = Activity::Output(Activity::Right, :success)
      left_output = Activity::Output(Activity::Left, :failure)

      nodes_attributes = [
        # id, task, data, [outputs]
        ["Start.default", start, {}, [right_output]],
        ["b", b, {}, [right_output, left_output]],
        ["c", c, {}, [right_output]],
        ["End.failure", failure, {stop_event: true}, []],
        ["End.success", success, {stop_event: true}, []],
      ]

      circuit = Activity::Circuit.new(
        wiring,
        [failure, success], # termini
        start_task: start
      )

      activity_outputs = [
        Activity::Output(failure, :failure),
        Activity::Output(success, :success)
      ]


      # add :wrap_static here.
      # config = {
      # }

      schema = Schema.new(
        circuit,
        activity_outputs,
        Schema::Nodes(nodes_attributes),
        config
      )

      @_flat_activity = Activity.new(schema)
    end
  end

  module NestingActivity
    def tasks(flat_activity:)
      @tasks ||= [
        start = Activity::Start.new(semantic: :default),
        # tasks
        a = Implementing.method(:a),
        flat_activity,
        # c = Implementing.method(:c),
        failure = Activity::End(:failure),
        success = Activity::End(:success),
      ]
    end

    def activity(wiring: nil, tasks: self.tasks, config: {})
      return @_nesting_activity if @_nesting_activity

      start, a, flat_activity, failure, success = tasks

      flat_activity_failure_output, flat_activity_success_output = flat_activity.to_h[:outputs]

      wiring ||= {
        start         => {Activity::Right => a},
        a             => {Activity::Right => flat_activity, Activity::Left => failure},
        flat_activity => {flat_activity_success_output.signal => success, flat_activity_failure_output.signal => failure},
      }

      # standard outputs, for introspection interface.
      right_output = Activity::Output(Activity::Right, :success)
      left_output = Activity::Output(Activity::Left, :failure)

      nodes_attributes = [
        # # id, task, data, [outputs]
        # ["Start.default", start, {}, [right_output]],
        # ["b", b, {}, [right_output, left_output]],
        # ["c", c, {}, [right_output]],
        # ["End.failure", failure, {stop_event: true}, []],
        # ["End.success", success, {stop_event: true}, []],
      ]

      circuit = Activity::Circuit.new(
        wiring,
        [failure, success], # termini
        start_task: start
      )

      activity_outputs = [
        Activity::Output(failure, :failure),
        Activity::Output(success, :success)
      ]

      schema = Schema.new(
        circuit,
        activity_outputs,
        Schema::Nodes(nodes_attributes),
        config
      )

      @_nesting_activity = Activity.new(schema)
    end
  end
end


Minitest::Spec.class_eval do
  include Fixtures # FIXME: remove

  include Fixtures::FlatActivity
  # include Fixtures::NestingActivity


  require "trailblazer/core"
  CU = Trailblazer::Core::Utils
end
