require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Circuit::Right, *args ] }
  B = ->(*args) { [ Circuit::Right, *args ] }
  C = ->(*args) { [ Circuit::Right, *args ] }
  D = ->(*args) { [ Circuit::Right, *args ] }

  let(:activity) do
    nested = bc
    seq = Activity.build do
      task A, id: "A"
      task nested, nested.outputs[:success] => :success, id: "<Nested>"
      task D, id: "D"
    end
  end

  let(:bc) do
    Activity.build do
      task B, id: "B"
      task C, id: "C"
    end
  end

  it do
    activity.({})
  end

  it do
    stack, _ = Trailblazer::Activity::Trace.( activity,
      [
        { content: "Let's start writing" }
      ]
    )
# pp stack
    output = Trailblazer::Activity::Trace::Present.tree(stack)

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- A
|-- <Nested>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- B
|   |-- C
|   `-- #<Trailblazer::Circuit::End:>
|-- D
`-- #<Trailblazer::Circuit::End:>}
  end
end
