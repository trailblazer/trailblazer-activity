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
      task nested, Output(nested.outputs.keys.first, :success) => :success, id: "<Nested>"
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

    output = Trailblazer::Activity::Trace::Present.tree(stack)

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- #<Proc:.rb:4 (lambda)>
|-- #<Trailblazer::Activity:>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- #<Proc:.rb:5 (lambda)>
|   |-- #<Proc:.rb:6 (lambda)>
|   |-- #<Trailblazer::Circuit::End:>
|   `-- #<Trailblazer::Activity:>
`-- #<Proc:.rb:7 (lambda)>}
  end
end
