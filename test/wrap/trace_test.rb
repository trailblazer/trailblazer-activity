require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

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

  it "traces flat activity" do
    stack, _ = Trailblazer::Activity::Trace.( bc,
      [
        { content: "Let's start writing" }
      ]
    )

    output = Trailblazer::Activity::Trace::Present.tree(stack)

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{|-- #<Trailblazer::Activity::Start:>
|-- B
|-- C
`-- #<Trailblazer::Activity::End:>}
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

    output.must_equal %{|-- #<Trailblazer::Activity::Start:>
|-- A
|-- <Nested>
|   |-- #<Trailblazer::Activity::Start:>
|   |-- B
|   |-- C
|   `-- #<Trailblazer::Activity::End:>
|-- D
`-- #<Trailblazer::Activity::End:>}
  end
end
