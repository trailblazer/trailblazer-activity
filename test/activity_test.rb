require "test_helper"

require "trailblazer/activity"

# Public API tests
# For Activity#call, see test/call_test.rb.

class ActivityTest < Minitest::Spec
  Circuit = Trailblazer::Circuit

  A = ->(*) { snippet }
  B = ->(*) { snippet }

  let(:end_for_success) { Circuit::End.new(:success) }

  let(:activity) do
    # Start   = Circuit::Start.new(:default)
    Trailblazer::Activity.from_wirings(
      [
        [ :attach!, target: [ A, id: "A", type: :task ], edge: [ Circuit::Right, type: :railway ] ],
        [ :attach!, source: "A", target: [ end_for_success, type: :event, role: :success, id: "End.success" ], edge: [ Circuit::Right, type: :railway ] ],
      ]
    )
  end

  describe "::from_wirings" do
    it do
      activity.circuit.to_fields.must_equal(
        [
          {
            activity.default_start_event => { Circuit::Right => A },
            A => { Circuit::Right => end_for_success }
          },
          [end_for_success],
          {}
        ]
      )
    end
  end

  describe "::merge" do
    it do
      wirings = [
        [ :insert_before!, "End.success", node: [ B, id: :B ], outgoing: [ Circuit::Right, type: :railway ], incoming: ->(edge) { edge[:type] == :railway } ]
      ]

      extended = Trailblazer::Activity.merge(activity, wirings)

      activity.circuit.to_fields.must_equal(
        [
          {
            activity.default_start_event => { Circuit::Right => A },
            A => { Circuit::Right => end_for_success }
          },
          [end_for_success],
          {}
        ]
      )

      extended.circuit.to_fields.must_equal(
        [
          {
            extended.default_start_event => { Circuit::Right => A },
            A => { Circuit::Right => B },
            B => { Circuit::Right => end_for_success }
          },
          [end_for_success],
          {}
        ]
      )
    end
  end

  describe "#outputs" do
    let(:end_for_failure) { Circuit::End.new(:fail) }
    let(:extended) { Trailblazer::Activity.merge(activity, [[ :attach!, source: "A", target: [ end_for_failure, role: :failure, id: "End.fail" ], edge: [ Circuit::Right, {} ] ]] ) }

    it { extended.outputs.must_equal( end_for_success => { role: :success }, end_for_failure => { role: :failure } ) }
  end
end

