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
      # signals
      right = Activity::Right
      left  = Activity::Left

      start, b, c, failure, success = tasks

      wiring ||= {
        start   => {right => b},
        b       => {right => c, left => failure},
        c       => {right => success},
        # failure => {},
        # success => {}
      }

      # standard outputs, for introspection interface.
      right_output = Activity::Output(Activity::Right, :success)
      left_output = Activity::Output(Activity::Right, :failure)

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
end


Minitest::Spec.class_eval do
  include Fixtures # FIXME: remove

  include Fixtures::FlatActivity


  require "trailblazer/core"
  CU = Trailblazer::Core::Utils
end
